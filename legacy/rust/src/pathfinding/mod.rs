//! A* pathfinding implementation

use std::cmp::Ordering;
use std::collections::BinaryHeap;

#[derive(Copy, Clone, Eq, PartialEq)]
struct AStarNode {
    x: usize,
    y: usize,
    f: u32,
    g: u32,
}

impl Ord for AStarNode {
    fn cmp(&self, other: &Self) -> Ordering {
        other
            .f
            .cmp(&self.f)
            .then_with(|| self.x.cmp(&other.x))
            .then_with(|| self.y.cmp(&other.y))
    }
}

impl PartialOrd for AStarNode {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

/// Find path using A* algorithm
pub fn find_path(
    start: (usize, usize),
    goal: (usize, usize),
    obstacles: &[Vec<bool>],
    width: usize,
    height: usize,
) -> Vec<(usize, usize)> {
    if goal.0 >= width || goal.1 >= height || obstacles[goal.0][goal.1] {
        return Vec::new();
    }
    if start == goal {
        return vec![start];
    }

    let mut open = BinaryHeap::new();
    let mut came_from = vec![vec![None; height]; width];
    let mut g_score = vec![vec![u32::MAX; height]; width];
    let mut closed = vec![vec![false; height]; width];

    g_score[start.0][start.1] = 0;
    let h = heuristic_cost(start.0, start.1, goal.0, goal.1);
    open.push(AStarNode {
        x: start.0,
        y: start.1,
        f: h,
        g: 0,
    });

    let dirs: [(i32, i32); 8] = [
        (0, 1),
        (1, 0),
        (0, -1),
        (-1, 0),
        (1, 1),
        (1, -1),
        (-1, 1),
        (-1, -1),
    ];

    while let Some(cur) = open.pop() {
        if cur.x == goal.0 && cur.y == goal.1 {
            let mut path = vec![goal];
            let mut pos = goal;
            while let Some(prev) = came_from[pos.0][pos.1] {
                path.push(prev);
                pos = prev;
            }
            path.reverse();
            return path;
        }

        if closed[cur.x][cur.y] {
            continue;
        }
        closed[cur.x][cur.y] = true;

        for (dx, dy) in dirs {
            let nx = cur.x as i32 + dx;
            let ny = cur.y as i32 + dy;
            if nx < 0 || nx >= width as i32 || ny < 0 || ny >= height as i32 {
                continue;
            }
            let (nx, ny) = (nx as usize, ny as usize);
            if obstacles[nx][ny]
                || closed[nx][ny]
                || diagonal_corner_blocked(cur.x, cur.y, nx, ny, obstacles)
            {
                continue;
            }

            let step_cost = if dx != 0 && dy != 0 { 14 } else { 10 };
            let tentative = cur.g + step_cost;
            if tentative < g_score[nx][ny] {
                came_from[nx][ny] = Some((cur.x, cur.y));
                g_score[nx][ny] = tentative;
                let h = heuristic_cost(nx, ny, goal.0, goal.1);
                open.push(AStarNode {
                    x: nx,
                    y: ny,
                    f: tentative + h,
                    g: tentative,
                });
            }
        }
    }
    Vec::new()
}

fn heuristic_cost(x: usize, y: usize, gx: usize, gy: usize) -> u32 {
    let dx = (gx as i32 - x as i32).unsigned_abs();
    let dy = (gy as i32 - y as i32).unsigned_abs();
    let min_d = dx.min(dy);
    let max_d = dx.max(dy);
    min_d * 14 + (max_d - min_d) * 10
}

fn diagonal_corner_blocked(
    cx: usize,
    cy: usize,
    nx: usize,
    ny: usize,
    obstacles: &[Vec<bool>],
) -> bool {
    if cx == nx || cy == ny {
        return false;
    }

    // Allow diagonal movement when at least one side-adjacent tile is free.
    // This keeps movement feeling fluid in 2D while still preventing
    // impossible "through-solid-corner" moves where both side tiles are blocked.
    obstacles[cx][ny] && obstacles[nx][cy]
}

#[cfg(test)]
mod tests {
    use super::find_path;

    #[test]
    fn supports_diagonal_paths_on_open_grid() {
        let width = 8;
        let height = 8;
        let obstacles = vec![vec![false; height]; width];

        let path = find_path((0, 0), (3, 3), &obstacles, width, height);

        assert!(!path.is_empty());
        assert_eq!(path.first().copied(), Some((0, 0)));
        assert_eq!(path.last().copied(), Some((3, 3)));

        let has_diagonal_step = path.windows(2).any(|pair| {
            let dx = pair[0].0.abs_diff(pair[1].0);
            let dy = pair[0].1.abs_diff(pair[1].1);
            dx == 1 && dy == 1
        });

        assert!(has_diagonal_step);
    }
}
