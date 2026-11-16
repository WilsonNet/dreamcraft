"use strict";

(() => {
	const canvas = document.getElementById("game");
	const ctx = canvas.getContext("2d");
	ctx.imageSmoothingEnabled = false;

	let ex = null;
	let imageData = null;
	let mode = "none";
	let patrolFirst = null;
	let lastTime = 0;
	let fps = 0;
	let fpsAccum = 0;
	let fpsFrames = 0;

	const imports = {
		odin_env: {
			write(fd, ptr, len) {
				if (!ex) return;
				const text = new TextDecoder().decode(new Uint8Array(ex.memory.buffer, ptr, len));
				if (fd === 2) console.error(text.trimEnd());
				else console.log(text.trimEnd());
			},
			rand_bytes(ptr, len) {
				if (!ex) return;
				new Uint8Array(ex.memory.buffer, ptr, len).fill(1);
			},
		},
	};

	async function boot() {
		let instance;
		try {
			const result = await WebAssembly.instantiateStreaming(fetch("main.wasm"), imports);
			instance = result.instance;
		} catch (_) {
			const bytes = await (await fetch("main.wasm")).arrayBuffer();
			const result = await WebAssembly.instantiate(bytes, imports);
			instance = result.instance;
		}
		ex = instance.exports;
		ex._start();
		window.dreamcraft.exports = ex;
		refreshAll();
		installInput();
		requestAnimationFrame(frame);
		window.dreamcraft.ready = true;
		console.log("DreamCraft web ready", ex.web_pixels_width(), "x", ex.web_pixels_height());
	}

	function readString(ptr, len) {
		return new TextDecoder().decode(new Uint8Array(ex.memory.buffer, ptr, len));
	}

	function refreshAll() {
		ex.web_refresh_state();
		ex.web_refresh_units();
		ex.web_refresh_fog();
		const state = JSON.parse(readString(ex.web_state_ptr(), ex.web_state_len()));
		const units = JSON.parse(readString(ex.web_units_ptr(), ex.web_units_len()));
		const fog = readString(ex.web_fog_ptr(), ex.web_fog_len());
		return { state, units, fog };
	}

	function frame(now) {
		if (!lastTime) lastTime = now;
		const dt = Math.min((now - lastTime) / 1000, 0.25);
		lastTime = now;
		ex.web_update(dt);
		const { state, units, fog } = refreshAll();
		drawPixels();
		updateHud(state, units, fog, dt);
		requestAnimationFrame(frame);
	}

	function drawPixels() {
		const width = ex.web_pixels_width();
		const height = ex.web_pixels_height();
		const source = new Uint8ClampedArray(ex.memory.buffer, ex.web_pixels_ptr(), width * height * 4);
		if (!imageData) imageData = new ImageData(width, height);
		imageData.data.set(source);
		ctx.putImageData(imageData, 0, 0);
	}

	function updateHud(state, units, fog, dt) {
		fpsAccum += dt;
		fpsFrames += 1;
		if (fpsAccum >= 0.5) {
			fps = Math.round(fpsFrames / fpsAccum);
			fpsAccum = 0;
			fpsFrames = 0;
		}
		const player = units.find((u) => u.team === "player");
		const selected = units.filter((u) => u.selected);
		document.getElementById("stats").textContent =
			`FPS ${fps}  |  Tick ${state.tick}  |  Fog ${state.fog_percent.toFixed(1)}%  |  ${state.alive_units} units`;
		document.getElementById("player").textContent = player
			? `Player (${player.position[0]}, ${player.position[1]})  HP ${player.hp}/${player.hp_max}  |  Waypoint ${state.waypoint}/${state.waypoints_total}`
			: "Player is dead";
		document.getElementById("selection").textContent = selected.length
			? `Selected ${selected.length}: ` + selected.map((u) => `(${u.position[0]},${u.position[1]})`).join(" ")
			: "No selection";
		const valid = document.getElementById("valid");
		valid.textContent = state.valid ? "INVARIANTS OK" : `INVALID: ${state.validation}`;
		valid.className = state.valid ? "ok" : "bad";
		document.getElementById("hash").textContent = `hash ${state.hash}`;
		document.getElementById("fog").textContent = fog;
		document.getElementById("level").textContent = state.game_over ? "PLAYER DEAD" : state.level_complete ? "LEVEL COMPLETE" : "";
		document.getElementById("mode").textContent = mode === "none" ? "Select" : mode === "move" ? "Move: click target" : patrolFirst ? "Patrol: click point B" : "Patrol: click point A";
	}

	function setMode(next) {
		mode = next;
		patrolFirst = null;
		for (const [id, value] of [["moveBtn", "move"], ["patrolBtn", "patrol"]]) {
			document.getElementById(id).classList.toggle("active", mode === value);
		}
	}

	function cellFromEvent(event) {
		const rect = canvas.getBoundingClientRect();
		const x = Math.floor(((event.clientX - rect.left) / rect.width) * 80);
		const y = Math.floor(((event.clientY - rect.top) / rect.height) * 50);
		return [Math.max(0, Math.min(79, x)), Math.max(0, Math.min(49, y))];
	}

	function installInput() {
		canvas.addEventListener("contextmenu", (e) => e.preventDefault());
		canvas.addEventListener("mousedown", (event) => {
			if (!ex) return;
			const [x, y] = cellFromEvent(event);
			if (event.button === 2) {
				if (!ex.web_attack(x, y)) ex.web_move(x, y);
				setMode("none");
				return;
			}
			if (event.button !== 0) return;
			if (mode === "move") {
				ex.web_move(x, y);
				setMode("none");
			} else if (mode === "patrol") {
				if (patrolFirst === null) {
					patrolFirst = [x, y];
				} else {
					ex.web_patrol(patrolFirst[0], patrolFirst[1], x, y);
					setMode("none");
				}
			} else {
				ex.web_select(x, y, event.shiftKey ? 1 : 0);
			}
		});
		document.getElementById("moveBtn").onclick = () => setMode(mode === "move" ? "none" : "move");
		document.getElementById("patrolBtn").onclick = () => setMode(mode === "patrol" ? "none" : "patrol");
		document.getElementById("stopBtn").onclick = () => { ex.web_stop(); setMode("none"); };
		document.getElementById("selectAllBtn").onclick = () => { ex.web_select_all(); };
		document.getElementById("resetBtn").onclick = () => { ex.web_reset(); setMode("none"); };
		window.addEventListener("keydown", (event) => {
			if (event.key === "Escape") setMode("none");
			if (event.key === "f" || event.key === "F") ex.web_select_all();
		});
	}

	function stateNow() {
		ex.web_refresh_state();
		return JSON.parse(readString(ex.web_state_ptr(), ex.web_state_len()));
	}

	function unitsNow() {
		ex.web_refresh_units();
		return JSON.parse(readString(ex.web_units_ptr(), ex.web_units_len()));
	}

	function result(ok, msg) {
		return Object.assign({ ok, msg }, stateNow());
	}

	function command(command) {
		if (!ex || !command || typeof command.cmd !== "string") {
			return { ok: false, msg: "invalid command" };
		}
		const x = Number(command.x || 0);
		const y = Number(command.y || 0);
		const x2 = Number(command.x2 || 0);
		const y2 = Number(command.y2 || 0);
		const value = Number(command.value || 0);
		const ticks = Math.max(1, Number(command.ticks || 1));
		switch (command.cmd) {
		case "status":
		case "state":
		case "snapshot":
			return result(true, "Status");
		case "goto":
		case "move":
			return result(ex.web_move(x, y) === 1, `Move to (${x},${y})`);
		case "patrol":
			return result(ex.web_patrol(x, y, x2, y2) === 1, "Patrol ordered");
		case "attack": {
			const hit = ex.web_attack(x, y) === 1;
			return result(hit, hit ? "Attack ordered" : "No visible enemy at target");
		}
		case "stop":
			return result(ex.web_stop() === 1, "Stopped");
		case "run":
		case "tick":
			ex.web_run(ticks);
			return result(true, `Ran ${ticks} ticks`);
		case "reset":
			ex.web_reset();
			return result(true, "Level reset");
		case "select":
			ex.web_select(x, y, 0);
			return result(true, "Selected");
		case "select_all":
			ex.web_select_all();
			return result(true, "Selected all players");
		case "spawn": {
			const team = command.team === "player" ? 0 : 1;
			const ok = ex.web_spawn(team, x, y, value) === 1;
			return result(ok, ok ? "Spawned" : "Spawn rejected");
		}
		case "kill": {
			const ok = ex.web_kill(x, y) === 1;
			return result(ok, ok ? "Killed" : "No unit at target");
		}
		case "set_hp": {
			const ok = ex.web_set_hp(x, y, value) === 1;
			return result(ok, ok ? "HP set" : "No unit at target");
		}
		case "teleport": {
			const ok = ex.web_teleport(x, y) === 1;
			return result(ok, ok ? "Teleported" : "Teleport rejected");
		}
		case "verify":
			return verify(command.verify || {});
		default:
			return result(false, `Unknown command: ${command.cmd}`);
		}
	}

	function verify(spec) {
		const state = stateNow();
		const units = unitsNow();
		const player = units.find((u) => u.team === "player");
		switch (spec.type) {
		case "player_at": {
			const ok = !!player && player.position[0] === Number(spec.x) && player.position[1] === Number(spec.y);
			const pos = player ? `${player.position[0]},${player.position[1]}` : "dead";
			return result(ok, ok ? "Player at expected position" : `Player at (${pos})`);
		}
		case "level_complete":
			return result(state.level_complete, state.level_complete ? "Level complete" : "Level not complete");
		case "enemy_dead": {
			const alive = units.some((u) => u.team === "enemy");
			return result(!alive, alive ? "Enemy alive" : "Enemy dead");
		}
		case "path_clear": {
			const ok = !!player && player.path_index >= player.path_len;
			return result(ok, ok ? "Player stopped" : "Player still moving");
		}
		case "valid":
			return result(state.valid, state.valid ? "State is valid" : `State invalid: ${state.validation}`);
		case "fog_visible": {
			const ok = ex.web_fog_state(Number(spec.x), Number(spec.y)) === 2;
			return result(ok, ok ? "Cell is visible" : "Cell is not visible");
		}
		case "blocked": {
			const ok = ex.web_is_blocked(Number(spec.x), Number(spec.y)) === 1;
			return result(ok, ok ? "Cell is blocked" : "Cell is walkable");
		}
		case "hash": {
			const ok = String(spec.value || "") === String(state.hash);
			return result(ok, `Hash ${state.hash}`);
		}
		default:
			return result(false, `Unknown verify type: ${spec.type}`);
		}
	}

	window.dreamcraft = {
		ready: false,
		exports: null,
		state: stateNow,
		units: unitsNow,
		fog: () => { ex.web_refresh_fog(); return readString(ex.web_fog_ptr(), ex.web_fog_len()); },
		command,
		reset: () => ex.web_reset(),
	};
	boot().catch((err) => {
		console.error(err);
		document.getElementById("valid").textContent = "WASM LOAD FAILED";
		document.getElementById("valid").className = "bad";
	});
})();
