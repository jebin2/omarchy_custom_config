use std::io;
use std::process::Command;
use std::time::{Duration, Instant};

use crossterm::{
    event::{
        self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, MouseButton, MouseEventKind,
    },
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Alignment, Constraint, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span, Text},
    widgets::{Block, Borders, BorderType, Paragraph, Padding, Wrap},
    Terminal,
};
use serde_json::Value;

#[derive(Debug, Clone)]
struct Window {
    id: String,
    class: String,
    title: String,
    workspace: String,
}

// Theme configuration
struct Theme {
    background: Color,
    surface: Color,
    surface_variant: Color,
    primary: Color,
    on_background: Color,
    on_surface: Color,
    accent: Color,
    border_selected: Color,
    border_normal: Color,
    error: Color,
}

impl Theme {
    // Dracula theme for a more attractive and visible UI
    fn dracula() -> Self {
        Theme {
            background: Color::Rgb(40, 42, 54),      // Dark background
            surface: Color::Rgb(68, 71, 90),         // Lighter background for UI elements
            surface_variant: Color::Rgb(98, 114, 164), // A lighter shade for selected items
            primary: Color::Rgb(189, 147, 249),      // Vibrant purple for primary accents
            on_background: Color::Rgb(248, 248, 242),  // Bright foreground for text
            on_surface: Color::Rgb(248, 248, 242),     // Bright foreground for text on surfaces
            accent: Color::Rgb(80, 250, 123),        // Bright green for secondary accents
            border_selected: Color::Rgb(255, 121, 198),// Striking pink for selected borders
            border_normal: Color::Rgb(98, 114, 164),   // Subdued border color
            error: Color::Rgb(255, 85, 85),          // Red for close/error actions
        }
    }
}

// Smart text wrapper that respects word boundaries
fn wrap_text(text: &str, width: usize, max_lines: usize) -> Vec<String> {
    if width == 0 {
        return vec![String::new()];
    }

    let mut lines = Vec::new();
    let mut current_line = String::new();

    for word in text.split_whitespace() {
        if word.len() > width {
            // Handle very long words by splitting them
            if !current_line.is_empty() {
                lines.push(current_line.clone());
                current_line.clear();
                if lines.len() >= max_lines {
                    break;
                }
            }

            let mut remaining = word;
            while !remaining.is_empty() && lines.len() < max_lines {
                let chunk_size = width.min(remaining.len());
                lines.push(remaining[..chunk_size].to_string());
                remaining = &remaining[chunk_size..];
            }
        } else if current_line.len() + word.len() + 1 <= width {
            if !current_line.is_empty() {
                current_line.push(' ');
            }
            current_line.push_str(word);
        } else {
            if !current_line.is_empty() {
                lines.push(current_line.clone());
                current_line.clear();
                if lines.len() >= max_lines {
                    break;
                }
            }
            current_line.push_str(word);
        }
    }

    if !current_line.is_empty() && lines.len() < max_lines {
        lines.push(current_line);
    }

    if lines.is_empty() {
        lines.push(String::new());
    }

    lines
}

fn get_windows() -> Vec<Window> {
    let output = Command::new("hyprctl")
        .arg("clients")
        .arg("-j")
        .output()
        .expect("failed to run hyprctl");

    let data: Value = serde_json::from_slice(&output.stdout).unwrap();
    data.as_array()
        .unwrap()
        .iter()
        .map(|c| Window {
            id: c["address"].as_str().unwrap_or("").to_string(),
            class: c["class"].as_str().unwrap_or("UnknownClass").to_string(),
            title: c["title"].as_str().unwrap_or("No Title").to_string(),
            workspace: c["workspace"]["id"]
                .as_i64()
                .map(|id| id.to_string())
                .unwrap_or("?".to_string()),
        })
        .collect()
}

struct App {
    running: bool,
    windows: Vec<Window>,
    selected_index: usize,
    theme: Theme,
}

impl App {
    fn new() -> Self {
        App {
            running: true,
            windows: get_windows(),
            selected_index: 0,
            theme: Theme::dracula(),
        }
    }

    fn get_app_icon(&self, class: &str) -> &'static str {
        match class.to_lowercase().as_str() {
            "firefox" | "firefox-esr" => "󰈹",
            "google-chrome" | "chromium" => "󰊯",
            "code" | "code-oss" | "vscodium" => "󰨞",
            "kitty" | "alacritty" | "wezterm" | "foot" => "󰆍",
            "thunar" | "nautilus" | "dolphin" | "pcmanfm" => "󰉋",
            "discord" => "󰙯",
            "slack" => "󰒱",
            "telegram" | "telegram-desktop" => "󰔿",
            "spotify" => "󰓇",
            "vlc" | "mpv" => "󰕼",
            "gimp" => "󰏘",
            "blender" => "󰂫",
            "libreoffice" => "󰈙",
            "steam" => "󰓓",
            "obsidian" => "󱓷",
            "notion" => "󰈚",
            _ => "󰣆",
        }
    }

    // Calculate optimal number of columns based on terminal width
    fn calculate_optimal_layout(&self, terminal_width: u16) -> (usize, usize, usize) {
        let min_cell_width = 25; // Minimum width for readable content
        let max_cols = (terminal_width as usize / min_cell_width).max(1);
        
        let optimal_cols = if self.windows.len() <= 3 {
            self.windows.len().max(1)
        } else if terminal_width < 80 {
            2
        } else if terminal_width < 120 {
            3
        } else {
            4
        }.min(max_cols);

        let cell_width = (terminal_width as usize / optimal_cols).saturating_sub(4); // Account for borders and padding
        let text_width = cell_width.saturating_sub(4); // Account for padding within cell
        
        (optimal_cols, cell_width, text_width)
    }

    fn close_selected_window(&mut self) {
        if let Some(win) = self.windows.get(self.selected_index) {
            let _ = Command::new("hyprctl")
                .arg("dispatch")
                .arg("closewindow")
                .arg(format!("address:{}", win.id))
                .output();
            
            // Remove the window from our list
            self.windows.remove(self.selected_index);
            
            // Adjust selection if needed
            if self.selected_index >= self.windows.len() && !self.windows.is_empty() {
                self.selected_index = self.windows.len() - 1;
            }
            
            // Exit if no windows left
            if self.windows.is_empty() {
                self.running = false;
            }
        }
    }

    fn refresh_windows(&mut self) {
        let old_selected_id = self.windows.get(self.selected_index).map(|w| w.id.clone());
        self.windows = get_windows();
        
        // Try to maintain selection on the same window
        if let Some(old_id) = old_selected_id {
            if let Some(new_index) = self.windows.iter().position(|w| w.id == old_id) {
                self.selected_index = new_index;
            } else if self.selected_index >= self.windows.len() && !self.windows.is_empty() {
                self.selected_index = self.windows.len() - 1;
            }
        }
        
        if self.windows.is_empty() {
            self.running = false;
        }
    }
}

fn render_header(frame: &mut ratatui::Frame, area: Rect, app: &App) {
    let header_text = Text::from(vec![
        Line::from(vec![
            Span::styled("󰖲 ", Style::default().fg(app.theme.accent)),
            Span::styled(
                "Hyprland Window Switcher",
                Style::default()
                    .fg(app.theme.on_background)
                    .add_modifier(Modifier::BOLD),
            ),
        ]),
        Line::from(vec![Span::styled(
            format!(
                "Found {} windows • Use ←→↑↓ or mouse • Enter/Click: focus • Del/x: close • r: refresh • q: quit",
                app.windows.len()
            ),
            Style::default().fg(app.theme.on_surface).add_modifier(Modifier::DIM),
        )]),
    ]);

    let header_block = Block::default()
        .padding(Padding::horizontal(2))
        .style(Style::default().bg(app.theme.background));

    let paragraph = Paragraph::new(header_text)
        .block(header_block)
        .alignment(Alignment::Center);

    frame.render_widget(paragraph, area);
}

fn render_windows(frame: &mut ratatui::Frame, area: Rect, app: &App) {
    let windows = &app.windows;
    let (cols, _, text_width) = app.calculate_optimal_layout(area.width);
    let rows = (windows.len() + cols - 1) / cols;

    let cell_height = 10; // Increased height to accommodate close button indicator
    let row_chunks = Layout::vertical(
        (0..rows)
            .map(|_| Constraint::Length(cell_height))
            .collect::<Vec<_>>(),
    )
    .split(area);

    for (i, win) in windows.iter().enumerate() {
        let row = i / cols;
        let col = i % cols;
        if row >= row_chunks.len() {
            continue;
        }
        let col_chunks = Layout::horizontal(
            (0..cols)
                .map(|_| Constraint::Ratio(1, cols as u32))
                .collect::<Vec<_>>(),
        )
        .split(row_chunks[row]);

        let is_selected = app.selected_index == i;
        let (bg_color, border_color, border_type) = if is_selected {
            (app.theme.surface_variant, app.theme.border_selected, BorderType::Thick)
        } else {
            (app.theme.surface, app.theme.border_normal, BorderType::Plain)
        };

        let block = Block::default()
            .borders(Borders::ALL)
            .border_type(border_type)
            .border_style(Style::default().fg(border_color))
            .style(Style::default().bg(bg_color))
            .padding(Padding::horizontal(1));

        let icon = app.get_app_icon(&win.class);
        let workspace_indicator = format!("󰋁 {}", win.workspace);

        // Calculate dynamic widths based on available space
        let class_width = text_width.saturating_sub(2); // Leave some margin
        let title_width = text_width;

        // Wrap class and title with dynamic width
        let wrapped_class: Vec<Line> = wrap_text(&win.class, class_width, 2)
            .into_iter()
            .map(|line| {
                Line::from(Span::styled(
                    line,
                    Style::default()
                        .fg(if is_selected { app.theme.on_background } else { app.theme.on_surface })
                        .add_modifier(Modifier::BOLD),
                ))
            })
            .collect();

        let wrapped_title: Vec<Line> = wrap_text(&win.title, title_width, 2)
            .into_iter()
            .map(|line| {
                Line::from(Span::styled(
                    line,
                    Style::default().fg(app.theme.on_surface),
                ))
            })
            .collect();

        let mut lines = Vec::new();
        // First line: icon and close indicator
        if is_selected {
            lines.push(Line::from(vec![
                Span::styled(format!("{} ", icon), Style::default().fg(app.theme.primary)),
                Span::styled("󰅖 Del/x to close", Style::default().fg(app.theme.error).add_modifier(Modifier::DIM)),
            ]));
        } else {
            lines.push(Line::from(vec![
                Span::styled(format!("{} ", icon), Style::default().fg(app.theme.primary)),
            ]));
        }
        lines.extend(wrapped_class);
        lines.extend(wrapped_title);
        lines.push(Line::from(Span::styled(
            workspace_indicator,
            Style::default().fg(app.theme.accent).add_modifier(Modifier::DIM),
        )));

        let paragraph = Paragraph::new(Text::from(lines))
            .block(block)
            .alignment(Alignment::Left)
            .wrap(Wrap { trim: true });

        frame.render_widget(paragraph, col_chunks[col]);
    }
}

/// Proper hit test using the same Layout as render_windows
fn hit_test(app: &App, mx: u16, my: u16, area: Rect) -> Option<usize> {
    let (cols, _, _) = app.calculate_optimal_layout(area.width);
    let rows = (app.windows.len() + cols - 1) / cols;

    let row_chunks = Layout::vertical(
        (0..rows)
            .map(|_| Constraint::Length(10)) // same as cell_height
            .collect::<Vec<_>>(),
    )
    .split(area);

    for row in 0..rows {
        let col_chunks = Layout::horizontal(
            (0..cols)
                .map(|_| Constraint::Ratio(1, cols as u32))
                .collect::<Vec<_>>(),
        )
        .split(row_chunks[row]);

        for col in 0..cols {
            let idx = row * cols + col;
            if idx >= app.windows.len() {
                continue;
            }
            let rect = col_chunks[col];
            if mx >= rect.x
                && mx < rect.x + rect.width
                && my >= rect.y
                && my < rect.y + rect.height
            {
                return Some(idx);
            }
        }
    }

    None
}

fn main() -> Result<(), io::Error> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut app = App::new();
    let tick_rate = Duration::from_millis(200);
    let mut last_tick = Instant::now();

    while app.running {
        terminal.draw(|f| {
            let size = f.size();
            let bg_block = Block::default().style(Style::default().bg(app.theme.background));
            f.render_widget(bg_block, size);

            let chunks = Layout::vertical([
                Constraint::Length(3),
                Constraint::Min(0),
            ])
            .split(size);

            render_header(f, chunks[0], &app);
            render_windows(f, chunks[1], &app);
        })?;

        let timeout = tick_rate
            .checked_sub(last_tick.elapsed())
            .unwrap_or_else(|| Duration::from_secs(0));

        if crossterm::event::poll(timeout)? {
            match event::read()? {
                Event::Key(key) => {
                    let current_size = terminal.size()?;
                    let (cols, _, _) = app.calculate_optimal_layout(current_size.width);
                    
                    match key.code {
                        KeyCode::Left => {
                            if app.selected_index > 0 {
                                app.selected_index -= 1;
                            }
                        }
                        KeyCode::Right => {
                            if app.selected_index + 1 < app.windows.len() {
                                app.selected_index += 1;
                            }
                        }
                        KeyCode::Up => {
                            if app.selected_index >= cols {
                                app.selected_index -= cols;
                            }
                        }
                        KeyCode::Down => {
                            if app.selected_index + cols < app.windows.len() {
                                app.selected_index += cols;
                            }
                        }
                        KeyCode::Enter => {
                            if let Some(win) = app.windows.get(app.selected_index) {
                                let _ = Command::new("hyprctl")
                                    .arg("dispatch")
                                    .arg("focuswindow")
                                    .arg(format!("address:{}", win.id))
                                    .spawn();
                            }
                            app.running = false;
                        }
                        KeyCode::Delete | KeyCode::Char('x') => {
                            app.close_selected_window();
                        }
                        KeyCode::Char('r') => {
                            app.refresh_windows();
                        }
                        KeyCode::Char('q') => app.running = false,
                        _ => {}
                    }
                },
                Event::Mouse(me) => match me.kind {
                    MouseEventKind::Moved => {
                        let chunks = Layout::vertical([Constraint::Length(3), Constraint::Min(0)])
                            .split(terminal.size()?);
                        if let Some(idx) = hit_test(&app, me.column, me.row, chunks[1]) {
                            app.selected_index = idx;
                        }
                    }
                    MouseEventKind::Down(MouseButton::Left) => {
                        if let Some(win) = app.windows.get(app.selected_index) {
                            let _ = Command::new("hyprctl")
                                .arg("dispatch")
                                .arg("focuswindow")
                                .arg(format!("address:{}", win.id))
                                .spawn();
                        }
                        app.running = false;
                    }
                    MouseEventKind::Down(MouseButton::Right) => {
                        // Right-click to close window
                        app.close_selected_window();
                    }
                    _ => {}
                },
                _ => {}
            }
        }

        if last_tick.elapsed() >= tick_rate {
            last_tick = Instant::now();
        }
    }

    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    Ok(())
}