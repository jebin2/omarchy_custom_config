use std::{
    io::{self, stdout},
    time::Duration,
};

use chrono::{Datelike, Local, NaiveDate};
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
    ExecutableCommand,
};
use ratatui::{
    prelude::*,
    widgets::{Block, Borders, Paragraph},
};

// --- Application State ---
struct App {
    running: bool,
    current_time: chrono::DateTime<Local>,
    selected_date: NaiveDate,
}

impl Default for App {
    fn default() -> Self {
        let now = Local::now();
        Self {
            running: true,
            current_time: now,
            selected_date: now.date_naive(),
        }
    }
}

impl App {
    fn tick(&mut self) { self.current_time = Local::now(); }
    fn reset_date(&mut self) { self.selected_date = Local::now().date_naive(); }

    fn next_month(&mut self) {
        let mut year = self.selected_date.year();
        let mut month = self.selected_date.month() + 1;
        if month > 12 { month = 1; year += 1; }
        self.selected_date = NaiveDate::from_ymd_opt(year, month, 1).unwrap_or(self.selected_date);
    }

    fn prev_month(&mut self) {
        let mut year = self.selected_date.year();
        let mut month = self.selected_date.month() as i32 - 1;
        if month < 1 { month = 12; year -= 1; }
        self.selected_date = NaiveDate::from_ymd_opt(year, month as u32, 1).unwrap_or(self.selected_date);
    }

    fn next_day(&mut self) {
        let last_day = last_day_of_month(self.selected_date.year(), self.selected_date.month()).day();
        
        if self.selected_date.day() < last_day {
            // Just go to next day in same month
            self.selected_date = self.selected_date.succ_opt().unwrap();
        } else {
            // Roll over to next month, day 1
            self.next_month();
            self.selected_date = NaiveDate::from_ymd_opt(
                self.selected_date.year(),
                self.selected_date.month(),
                1,
            ).unwrap_or(self.selected_date);
        }
    }

    fn prev_day(&mut self) {
        if self.selected_date.day() > 1 {
            // Just go to previous day in same month
            self.selected_date = self.selected_date.pred_opt().unwrap();
        } else {
            // Roll over to last day of previous month
            self.prev_month();
            let last_day = last_day_of_month(self.selected_date.year(), self.selected_date.month()).day();
            self.selected_date = NaiveDate::from_ymd_opt(
                self.selected_date.year(),
                self.selected_date.month(),
                last_day,
            ).unwrap_or(self.selected_date);
        }
    }
    fn next_week(&mut self) {
        // Add 7 days, handling month/year rollover automatically
        if let Some(new_date) = self.selected_date.checked_add_days(chrono::Days::new(7)) {
            self.selected_date = new_date;
        }
        // If somehow it fails (unlikely), do nothing
    }

    fn prev_week(&mut self) {
        // Subtract 7 days, handling month/year rollover automatically
        if let Some(new_date) = self.selected_date.checked_sub_days(chrono::Days::new(7)) {
            self.selected_date = new_date;
        }
        // If somehow it fails (unlikely), do nothing
    }
}

// --- Main Application Logic ---
fn main() -> io::Result<()> {
    stdout().execute(EnterAlternateScreen)?;
    enable_raw_mode()?;
    let mut terminal = Terminal::new(CrosstermBackend::new(stdout()))?;
    let mut app = App::default();

    while app.running {
        terminal.draw(|frame| ui(frame, &app))?;

        if event::poll(Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    match key.code {
                        KeyCode::Char('q') => app.running = false,
                        KeyCode::Char('r') => app.reset_date(),
                        KeyCode::Char('n') => app.next_month(),
                        KeyCode::Char('p') => app.prev_month(),
                        KeyCode::Left => app.prev_day(),
                        KeyCode::Right => app.next_day(),
                        KeyCode::Up => app.prev_week(),
                        KeyCode::Down => app.next_week(),
                        _ => {}
                    }
                }
            }
        }
        app.tick();
    }

    stdout().execute(LeaveAlternateScreen)?;
    disable_raw_mode()?;
    Ok(())
}

// --- UI Rendering Logic ---
fn ui(frame: &mut Frame, app: &App) {
    let pink = Color::Rgb(255, 105, 180);
    let white = Color::Rgb(220, 220, 220);
    let gray = Color::Rgb(150, 150, 150);

    // Make the calendar responsive to terminal size
    let area = centered_rect(50, 25, frame.size()); // Increased from 45x19 to 60x25
    
    let chunks = Layout::vertical([
        Constraint::Length(3),  // Clock
        Constraint::Length(1),  // Spacer
        Constraint::Length(1),  // Calendar Title
        Constraint::Length(9),  // Calendar (fixed 9 lines: 1 header + 6 weeks + 2 border)
        Constraint::Length(1),  // Spacer
        Constraint::Length(1),  // Controls Title
        Constraint::Length(5),  // Controls (increased from 4 to 5)
        Constraint::Min(0),     // Flexible spacer at bottom
    ])
    .split(area);

    render_clock(frame, chunks[0], app, pink, white);
    render_title(frame, chunks[2], app.selected_date.format("%B %Y").to_string(), pink);
    render_calendar(frame, chunks[3], app, pink, white, gray);
    render_title(frame, chunks[5], "CONTROLS".to_string(), pink);
    render_controls(frame, chunks[6], pink, white);
}

fn render_clock(frame: &mut Frame, area: Rect, app: &App, border_color: Color, text_color: Color) {
    let time_str = app.current_time.format("%H:%M:%S").to_string();
    let block = Block::default().borders(Borders::ALL).border_style(Style::new().fg(border_color));
    let paragraph = Paragraph::new(time_str).block(block).style(Style::new().fg(text_color)).alignment(Alignment::Center);
    frame.render_widget(paragraph, area);
}

fn render_title(frame: &mut Frame, area: Rect, title_text: String, color: Color) {
    let title = format!("{}", title_text);
    let paragraph = Paragraph::new(title).style(Style::new().fg(color)).alignment(Alignment::Center);
    frame.render_widget(paragraph, area);
}

fn render_calendar(
    frame: &mut Frame,
    area: Rect,
    app: &App,
    border_color: Color,
    text_color: Color,
    header_color: Color,
) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::new().fg(border_color));
    frame.render_widget(block, area);

    let inner_area = area.inner(&Margin { vertical: 1, horizontal: 1 });
    let today = Local::now().date_naive();
    let month_data = generate_month_grid(app.selected_date.year(), app.selected_date.month());

    // Use fixed constraints for more predictable layout
    let rows = Layout::vertical([
        Constraint::Length(1),       // Header
        Constraint::Length(1),       // Week 1
        Constraint::Length(1),       // Week 2
        Constraint::Length(1),       // Week 3
        Constraint::Length(1),       // Week 4
        Constraint::Length(1),       // Week 5
        Constraint::Length(1),       // Week 6
    ])
    .split(inner_area);

    // Render weekdays header
    let header_cols = Layout::horizontal([Constraint::Ratio(1, 7); 7]).split(rows[0]);
    let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    for (i, day) in days.iter().enumerate() {
        frame.render_widget(
            Paragraph::new(*day)
                .alignment(Alignment::Center)
                .style(Style::new().fg(header_color)),
            header_cols[i],
        );
    }

    // Render each week
    for (week_idx, week) in month_data.iter().enumerate() {
        if week_idx >= 6 { break; } // Safety check
        let week_area = rows[week_idx + 1]; // skip header
        let day_cols = Layout::horizontal([Constraint::Ratio(1, 7); 7]).split(week_area);
        
        for (day_idx, &day) in week.iter().enumerate() {
            if let Some(day_val) = day {
                let current_date = NaiveDate::from_ymd_opt(
                    app.selected_date.year(),
                    app.selected_date.month(),
                    day_val,
                )
                .unwrap();

                let mut style = Style::new().fg(text_color);
                if current_date == app.selected_date {
                    style = style.bg(text_color).fg(Color::Black);
                } else if current_date == today {
                    style = style.add_modifier(Modifier::BOLD);
                }

                frame.render_widget(
                    Paragraph::new(format!("{:>2}", day_val)) // Right-align numbers for better appearance
                        .alignment(Alignment::Center)
                        .style(style),
                    day_cols[day_idx],
                );
            }
        }
    }
}

fn render_controls(frame: &mut Frame, area: Rect, border_color: Color, text_color: Color) {
    let block = Block::default().borders(Borders::ALL).border_style(Style::new().fg(border_color));
        let text = vec![
        Line::from(vec![
            Span::raw(" "),
            Span::styled("[n/p]", Style::new().fg(border_color).add_modifier(Modifier::BOLD)),
            Span::styled(" : Next/Prev Month", Style::new().fg(text_color)),
        ]),
        Line::from(vec![
            Span::raw(" "),
            Span::styled("[←→][↑↓]", Style::new().fg(border_color).add_modifier(Modifier::BOLD)),
            Span::styled(" : Navigate Day", Style::new().fg(text_color)),
        ]),
        Line::from(vec![
            Span::raw(" "),
            Span::styled("[q]", Style::new().fg(border_color).add_modifier(Modifier::BOLD)),
            Span::styled("   : Quit", Style::new().fg(text_color)),
        ]),
    ];
    let paragraph = Paragraph::new(text).block(block).alignment(Alignment::Left);
    frame.render_widget(paragraph, area);
}

// --- Helper Functions ---

fn generate_month_grid(year: i32, month: u32) -> Vec<Vec<Option<u32>>> {
    let first_day = NaiveDate::from_ymd_opt(year, month, 1).unwrap();
    let start_weekday = first_day.weekday().num_days_from_sunday();
    let last_day = last_day_of_month(year, month).day();

    let mut grid = vec![vec![None; 7]; 6];
    let mut current_day = 1;

    for week in 0..6 {
        for day in 0..7 {
            if (week == 0 && day < start_weekday as usize) || current_day > last_day {
                continue;
            }
            grid[week][day] = Some(current_day);
            current_day += 1;
        }
    }
    grid
}

fn last_day_of_month(year: i32, month: u32) -> NaiveDate {
    NaiveDate::from_ymd_opt(year, month + 1, 1)
        .unwrap_or_else(|| NaiveDate::from_ymd_opt(year + 1, 1, 1).unwrap())
        .pred_opt()
        .unwrap()
}

fn centered_rect(width: u16, height: u16, r: Rect) -> Rect {
    // Add minimum size checks
    let actual_width = width.min(r.width);
    let actual_height = height.min(r.height);
    
    let popup_layout = Layout::vertical([
        Constraint::Length((r.height.saturating_sub(actual_height)) / 2),
        Constraint::Length(actual_height),
        Constraint::Length((r.height.saturating_sub(actual_height)) / 2),
    ])
    .split(r);

    Layout::horizontal([
        Constraint::Length((r.width.saturating_sub(actual_width)) / 2),
        Constraint::Length(actual_width),
        Constraint::Length((r.width.saturating_sub(actual_width)) / 2),
    ])
    .split(popup_layout[1])[1]
}
