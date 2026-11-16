// Minimal localhost HTTP/JSON control server.
//
// Single-threaded and polled from the main loop, so commands mutate the same
// Game value as rendering and fixed-step simulation.
package control

import "core:encoding/json"
import "core:fmt"
import "core:net"
import "core:strconv"
import "core:strings"
import "core:time"
import g "../game"

Screenshot_Proc :: proc(user: rawptr) -> (data: []byte, ok: bool)

Server :: struct {
	listener: net.TCP_Socket,
	game: ^g.Game,
	port: int,
	running: bool,
	screenshot: Screenshot_Proc,
	screenshot_user: rawptr,
}

server_start :: proc(
	server: ^Server,
	game: ^g.Game,
	port: int,
	screenshot: Screenshot_Proc = nil,
	screenshot_user: rawptr = nil,
) -> bool {
	server.game = game
	server.port = port
	server.screenshot = screenshot
	server.screenshot_user = screenshot_user
	endpoint := net.Endpoint{address = net.IP4_Loopback, port = port}
	listener, err := net.listen_tcp(endpoint, 16)
	server.listener = listener
	if err != nil {
		fmt.eprintfln("control server: listen on 127.0.0.1:%d failed: %v", port, err)
		return false
	}
	if block_err := net.set_blocking(listener, false); block_err != .None {
		fmt.eprintfln("control server: cannot set non-blocking: %v", block_err)
		net.close(listener)
		return false
	}
	server.running = true
	fmt.printfln("Control API: http://127.0.0.1:%d/state", port)
	return true
}

server_close :: proc(server: ^Server) {
	if server.running {
		net.close(server.listener)
		server.running = false
	}
}

server_poll :: proc(server: ^Server) {
	if !server.running {
		return
	}
	for _ in 0..<8 {
		client, _, err := net.accept_tcp(server.listener)
		if err == .Would_Block {
			return
		}
		if err != .None {
			return
		}
		handle_client(server, client)
	}
}

@(private)
handle_client :: proc(server: ^Server, client: net.TCP_Socket) {
	defer net.close(client)
	defer free_all(context.temp_allocator)
	_ = net.set_blocking(client, true)
	_ = net.set_option(client, .Receive_Timeout, 250 * time.Millisecond)
	_ = net.set_option(client, .Send_Timeout, 1000 * time.Millisecond)

	buffer: [16384]u8
	length, header_end, content_length, ok := read_http_request(client, buffer[:])
	if !ok {
		send_response(client, 400, "text/plain", transmute([]byte)string("bad request\n"))
		return
	}
	method, path, body := parse_http_request(buffer[:length], header_end, content_length)
	route(server, client, method, path, body)
}

@(private)
read_http_request :: proc(
	client: net.TCP_Socket,
	buffer: []u8,
) -> (length, header_end, content_length: int, ok: bool) {
	header_end = -1
	for {
		if header_end < 0 {
			if index := strings.index(string(buffer[:length]), "\r\n\r\n"); index >= 0 {
				header_end = index + 4
				content_length = parse_content_length(buffer[:header_end])
				if content_length < 0 {
					return 0, 0, 0, false
				}
			}
		}
		if header_end >= 0 && length >= header_end + content_length {
			return length, header_end, content_length, true
		}
		if length >= len(buffer) {
			return 0, 0, 0, false
		}
		read, err := net.recv_tcp(client, buffer[length:])
		if err != .None {
			if err == .Timeout && length > 0 {
				return 0, 0, 0, false
			}
			return 0, 0, 0, false
		}
		if read == 0 {
			return 0, 0, 0, false
		}
		length += read
	}
}

@(private)
parse_content_length :: proc(header: []u8) -> int {
	lines := strings.split(string(header), "\r\n")
	defer delete(lines)
	for line in lines[1:] {
		colon := strings.index_byte(line, ':')
		if colon < 0 {
			continue
		}
		name := strings.trim_space(line[:colon])
		if strings.equal_fold(name, "Content-Length") {
			value := strings.trim_space(line[colon + 1:])
			if parsed, ok := strconv.parse_int(value); ok {
				return parsed
			}
			return -1
		}
	}
	return 0
}

@(private)
parse_http_request :: proc(
	data: []byte,
	header_end, content_length: int,
) -> (method, path, body: string) {
	lines := strings.split_n(string(data[:header_end]), "\r\n", 3)
	defer delete(lines)
	parts := strings.split_n(lines[0], " ", 4)
	defer delete(parts)
	if len(parts) >= 2 {
		method = parts[0]
		path = parts[1]
		if query := strings.index_byte(path, '?'); query >= 0 {
			path = path[:query]
		}
	}
	if content_length > 0 {
		body = string(data[header_end:header_end + content_length])
	}
	return
}

@(private)
route :: proc(server: ^Server, client: net.TCP_Socket, method, path, body: string) {
	switch method {
	case "OPTIONS":
		send_response(client, 204, "text/plain", nil)
	case "GET":
		handle_get(server, client, path)
	case "POST":
		if path == "/command" {
			handle_command(server, client, body)
		} else {
			send_response(client, 404, "application/json", transmute([]byte)string(`{"ok":false,"msg":"not found"}`))
		}
	case:
		send_response(client, 405, "text/plain", transmute([]byte)string("method not allowed\n"))
	}
}

@(private)
handle_get :: proc(server: ^Server, client: net.TCP_Socket, path: string) {
	switch path {
	case "/", "/health", "/state":
		if path == "/health" {
			send_response(client, 200, "application/json", transmute([]byte)string(`{"ok":true}`))
		} else {
			send_json(client, encode_snapshot(server.game))
		}
	case "/units":
		send_json(client, encode_units(server.game))
	case "/fog":
		buffer: [g.GRID_CELLS + g.GRID_H]u8
		length := fog_text(server.game, buffer[:])
		send_response(client, 200, "text/plain; charset=utf-8", buffer[:length])
	case "/screenshot":
		if server.screenshot == nil {
			send_response(client, 501, "application/json", transmute([]byte)string(`{"ok":false,"msg":"screenshot not available in this build"}`))
			return
		}
		data, ok := server.screenshot(server.screenshot_user)
		if !ok || data == nil {
			send_response(client, 501, "application/json", transmute([]byte)string(`{"ok":false,"msg":"screenshot capture failed"}`))
			return
		}
		defer delete(data)
		send_response(client, 200, "image/png", data)
	case:
		send_response(client, 404, "application/json", transmute([]byte)string(`{"ok":false,"msg":"not found"}`))
	}
}

@(private)
handle_command :: proc(server: ^Server, client: net.TCP_Socket, body: string) {
	command: Command
	if err := json.unmarshal_string(body, &command, allocator = context.temp_allocator); err != nil {
		send_response(client, 400, "application/json", transmute([]byte)string(`{"ok":false,"msg":"invalid json"}`))
		return
	}
	result := execute(server.game, command)
	data, err := json.marshal(result)
	if err != nil {
		send_response(client, 500, "application/json", transmute([]byte)string(`{"ok":false,"msg":"marshal failed"}`))
		return
	}
	defer delete(data)
	send_response(client, 200, "application/json", data)
}

@(private)
send_json :: proc(client: net.TCP_Socket, data: []byte, err: json.Marshal_Error) {
	if err != nil {
		send_response(client, 500, "application/json", transmute([]byte)string(`{"ok":false,"msg":"marshal failed"}`))
		return
	}
	defer delete(data)
	send_response(client, 200, "application/json", data)
}

@(private)
send_response :: proc(client: net.TCP_Socket, status: int, content_type: string, body: []byte) {
	header: [512]u8
	text := fmt.bprintf(
		header[:len(header) - 1],
		"HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\n\r\n",
		status,
		status_text(status),
		content_type,
		len(body),
	)
	header[len(text)] = 0
	if !send_all(client, transmute([]byte)text) {
		return
	}
	if len(body) > 0 {
		_ = send_all(client, body)
	}
}

@(private)
send_all :: proc(client: net.TCP_Socket, data: []byte) -> bool {
	offset := 0
	for offset < len(data) {
		written, err := net.send_tcp(client, data[offset:])
		if err != .None || written <= 0 {
			return false
		}
		offset += written
	}
	return true
}

@(private)
status_text :: proc(status: int) -> string {
	switch status {
	case 200:
		return "OK"
	case 204:
		return "No Content"
	case 400:
		return "Bad Request"
	case 404:
		return "Not Found"
	case 405:
		return "Method Not Allowed"
	case 500:
		return "Internal Server Error"
	case 501:
		return "Not Implemented"
	}
	return "OK"
}
