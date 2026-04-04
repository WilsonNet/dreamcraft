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

    let mut open = BinaryHeap::new();
    let mut came_from = vec![vec![None; height]; width];
    let mut g_score = vec![vec![u32::MAX; height]; width];
    let mut closed = vec![vec![false; height]; width];

    g_score[start.0][start.1] = 0;
    let h =
        ((goal.0 as i32 - start.0 as i32).abs() + (goal.1 as i32 - start.1 as i32).abs()) as u32;
    open.push(AStarNode {
        x: start.0,
        y: start.1,
        f: h,
        g: 0,
    });

    let dirs: [(i32, i32); 4] = [(0, 1), (1, 0), (0, -1), (-1, 0)];

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
            if obstacles[nx][ny] || closed[nx][ny] {
                continue;
            }

            let tentative = cur.g + 1;
            if tentative < g_score[nx][ny] {
                came_from[nx][ny] = Some((cur.x, cur.y));
                g_score[nx][ny] = tentative;
                let h =
                    ((goal.0 as i32 - nx as i32).abs() + (goal.1 as i32 - ny as i32).abs()) as u32;
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
