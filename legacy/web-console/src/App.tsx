import React, { useState, useRef, useEffect } from 'react';

interface GameState {
  playerX: number;
  playerY: number;
  goalX: number;
  gridWidth: number;
  gridHeight: number;
  levelComplete: boolean;
  obstacles: string;
}

declare global {
  interface Window {
    dreamcraft?: {
      getState: () => GameState;
      moveTo: (x: number, y: number) => void;
      testPath: (fromX: number, fromY: number, toX: number, toY: number) => number;
      resetLevel: () => void;
    };
  }
}

const COMMANDS = [
  { cmd: 'help', desc: 'Show this help message' },
  { cmd: 'status', desc: 'Show current game state' },
  { cmd: 'goto <x> <y>', desc: 'Move player to position' },
  { cmd: 'path <x> <y>', desc: 'Test pathfinding to position' },
  { cmd: 'reset', desc: 'Reset level' },
  { cmd: 'run', desc: 'Auto-complete the level' },
  { cmd: 'obstacles', desc: 'Show obstacle grid' },
  { cmd: 'clear', desc: 'Clear console' },
];

const App: React.FC = () => {
  const [output, setOutput] = useState<string[]>([
    'DreamCraft Console v1.0',
    'Type "help" for available commands',
    '─────────────────────────────────'
  ]);
  const [input, setInput] = useState('');
  const [gameState, setGameState] = useState<GameState | null>(null);
  const [running, setRunning] = useState(false);
  const consoleRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (consoleRef.current) {
      consoleRef.current.scrollTop = consoleRef.current.scrollHeight;
    }
  }, [output]);

  useEffect(() => {
    const interval = setInterval(() => {
      if (window.dreamcraft) {
        setGameState(window.dreamcraft.getState());
      }
    }, 500);
    return () => clearInterval(interval);
  }, []);

  const addOutput = (text: string) => {
    setOutput(prev => [...prev, text]);
  };

  const parseCommand = (cmd: string): string[] => {
    return cmd.trim().toLowerCase().split(/\s+/);
  };

  const runCommand = (cmd: string) => {
    const parts = parseCommand(cmd);
    const command = parts[0];
    const args = parts.slice(1);

    addOutput(`> ${cmd}`);

    switch (command) {
      case 'help':
        addOutput('Available commands:');
        COMMANDS.forEach(c => addOutput(`  ${c.cmd.padEnd(15)} - ${c.desc}`));
        break;

      case 'status':
        if (window.dreamcraft) {
          const state = window.dreamcraft.getState();
          addOutput(`Player: (${state.playerX}, ${state.playerY})`);
          addOutput(`Goal: (${state.goalX}, ${state.gridHeight / 2})`);
          addOutput(`Grid: ${state.gridWidth}x${state.gridHeight}`);
          addOutput(`Level Complete: ${state.levelComplete ? 'YES!' : 'No'}`);
        } else {
          addOutput('ERROR: Game not loaded');
        }
        break;

      case 'goto':
        if (args.length < 2) {
          addOutput('Usage: goto <x> <y>');
        } else {
          const x = parseInt(args[0]);
          const y = parseInt(args[1]);
          if (window.dreamcraft) {
            window.dreamcraft.moveTo(x, y);
            addOutput(`Moving to (${x}, ${y})...`);
          }
        }
        break;

      case 'path':
        if (args.length < 2) {
          addOutput('Usage: path <x> <y>');
        } else {
          const x = parseInt(args[0]);
          const y = parseInt(args[1]);
          if (window.dreamcraft) {
            const state = window.dreamcraft.getState();
            const steps = window.dreamcraft.testPath(state.playerX, state.playerY, x, y);
            if (steps > 0) {
              addOutput(`Path found: ${steps} steps`);
            } else {
              addOutput('No path found (blocked by obstacles)');
            }
          }
        }
        break;

      case 'reset':
        if (window.dreamcraft) {
          window.dreamcraft.resetLevel();
          addOutput('Level reset');
        }
        break;

      case 'run':
        if (!window.dreamcraft) {
          addOutput('ERROR: Game not loaded');
          break;
        }
        setRunning(true);
        addOutput('Auto-completing level...');
        autoComplete();
        break;

      case 'obstacles':
        if (window.dreamcraft) {
          const state = window.dreamcraft.getState();
          addOutput(`Obstacles at: ${state.obstacles}`);
        }
        break;

      case 'clear':
        setOutput([]);
        break;

      case '':
        break;

      default:
        addOutput(`Unknown command: ${command}`);
        addOutput('Type "help" for available commands');
    }
  };

  const autoComplete = async () => {
    if (!window.dreamcraft || !running) return;

    const state = window.dreamcraft.getState();
    
    if (state.levelComplete) {
      setRunning(false);
      addOutput('✓ Level completed!');
      return;
    }

    const waypoints = [
      (state.gridWidth / 4),
      (state.gridWidth / 2),
      (state.gridWidth * 3 / 4),
      (state.gridWidth - 3),
    ];

    for (const targetX of waypoints) {
      if (!running) break;
      
      const targetY = Math.floor(state.gridHeight / 2);
      const currentX = window.dreamcraft.getState().playerX;
      
      if (currentX < targetX) {
        addOutput(`Moving to (${Math.floor(targetX)}, ${targetY})...`);
        window.dreamcraft.moveTo(Math.floor(targetX), targetY);
        
        while (window.dreamcraft.getState().playerX < targetX - 2 && running) {
          await new Promise(r => setTimeout(r, 100));
        }
      }
    }

    setRunning(false);
    const finalState = window.dreamcraft.getState();
    if (finalState.levelComplete) {
      addOutput('✓ Level completed!');
    } else {
      addOutput(`Still at (${finalState.playerX}, ${finalState.playerY})`);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (input.trim()) {
      runCommand(input);
      setInput('');
    }
  };

  return (
    <div style={{
      position: 'absolute', top: 0, left: 0, right: 0, bottom: 0,
      display: 'flex', flexDirection: 'column',
      background: 'linear-gradient(135deg, #0a0a0a 0%, #1a1a2e 100%)',
      fontFamily: 'Consolas, Monaco, monospace',
      color: '#00ff00'
    }}>
      <div style={{
        padding: '15px 20px',
        borderBottom: '1px solid #333',
        display: 'flex', justifyContent: 'space-between', alignItems: 'center'
      }}>
        <div>
          <span style={{ fontSize: 18, fontWeight: 'bold', color: '#00ff00' }}>
            DreamCraft Console
          </span>
          <span style={{ marginLeft: 20, color: '#888', fontSize: 12 }}>
            Browser-based Level Tester
          </span>
        </div>
        {gameState && (
          <div style={{ display: 'flex', gap: 20, fontSize: 13 }}>
            <span>Player: <span style={{ color: '#4af' }}>({gameState.playerX}, {gameState.playerY})</span></span>
            <span>Goal: <span style={{ color: '#fa0' }}>({gameState.goalX}, {Math.floor(gameState.gridHeight / 2)})</span></span>
            <span style={{ color: gameState.levelComplete ? '#0f0' : '#f55' }}>
              {gameState.levelComplete ? '✓ COMPLETE' : 'In Progress'}
            </span>
          </div>
        )}
      </div>

      <div
        ref={consoleRef}
        style={{
          flex: 1,
          overflow: 'auto',
          padding: 15,
          fontSize: 13,
          lineHeight: 1.6
        }}
      >
        {output.map((line, i) => (
          <div key={i} style={{
            color: line.startsWith('>') ? '#fff' :
                   line.startsWith('✓') ? '#0f0' :
                   line.startsWith('ERROR') ? '#f55' :
                   line.startsWith('Moving') ? '#4af' :
                   line.includes('found') ? '#fa0' : '#aaa'
          }}>
            {line}
          </div>
        ))}
      </div>

      <form onSubmit={handleSubmit} style={{
        padding: 15,
        borderTop: '1px solid #333',
        display: 'flex',
        alignItems: 'center',
        background: '#111'
      }}>
        <span style={{ color: '#0f0', marginRight: 10, fontSize: 16 }}>{'>'}</span>
        <input
          ref={inputRef}
          type="text"
          value={input}
          onChange={e => setInput(e.target.value)}
          placeholder="Type command (try 'help')"
          disabled={running}
          style={{
            flex: 1,
            background: 'transparent',
            border: 'none',
            outline: 'none',
            color: '#fff',
            fontSize: 14,
            fontFamily: 'inherit'
          }}
        />
        {running && (
          <button
            type="button"
            onClick={() => setRunning(false)}
            style={{
              marginLeft: 10,
              padding: '5px 15px',
              background: '#f55',
              border: 'none',
              borderRadius: 3,
              color: '#fff',
              cursor: 'pointer'
            }}
          >
            STOP
          </button>
        )}
      </form>
    </div>
  );
};

export default App;
