#!/bin/bash

show_ports() {
  local term_width=$(tput cols)
  local addr_width=35 # adjustable width for ADDRESS
  local pid_width=8
  local cmd_width=$((term_width - addr_width - pid_width - 10))

  if [ $cmd_width -lt 30 ]; then
    cmd_width=30
  fi

  ss -tulnp 2>/dev/null | awk -v addr_width="$addr_width" -v pid_width="$pid_width" -v cmd_width="$cmd_width" '
    function wrap_text(text, width) {
        if (length(text) <= width) return text
        result = ""
        while (length(text) > width) {
            pos = width
            while (pos > 0 && substr(text, pos, 1) != " ") pos--
            if (pos == 0) pos = width
            if (result != "") result = result "\n"
            result = result substr(text, 1, pos)
            text = substr(text, pos + 1)
        }
        if (length(text) > 0) {
            if (result != "") result = result "\n"
            result = result text
        }
        return result
    }

    function print_border() {
        printf "+"
        for (i = 0; i < addr_width+2; i++) printf "-"
        printf "+"
        for (i = 0; i < pid_width+2; i++) printf "-"
        printf "+"
        for (i = 0; i < cmd_width+2; i++) printf "-"
        printf "+\n"
    }

    function print_row(addr, pid, cmd) {
        wrapped_addr = wrap_text(addr, addr_width)
        wrapped_cmd  = wrap_text(cmd, cmd_width)
        split(wrapped_addr, addr_lines, "\n")
        split(wrapped_cmd, cmd_lines, "\n")
        max_lines = (length(addr_lines) > length(cmd_lines) ? length(addr_lines) : length(cmd_lines))

        for (i = 1; i <= max_lines; i++) {
            printf "| %-*s | %-*s | %-*s |\n",
                   addr_width, (i <= length(addr_lines) ? addr_lines[i] : ""),
                   pid_width,  (i == 1 ? pid : ""),
                   cmd_width,  (i <= length(cmd_lines) ? cmd_lines[i] : "")
        }
        print_border()
    }

    BEGIN {
        print_border()
        printf "| %-*s | %-*s | %-*s |\n", addr_width, "ADDRESS", pid_width, "PID", cmd_width, "COMMAND"
        print_border()
    }

    NR > 1 {
        addr=$5
        gsub(/%.*$/, "", addr)   # remove %lo, %wlan0, etc
        pidcomm=$7
        if (pidcomm ~ /pid=[0-9]+/) {
            match(pidcomm, /pid=([0-9]+)/, m)
            pid=m[1]
            cmd=""; while ((getline line < ("/proc/"pid"/cmdline")) > 0) {
                gsub(/\0/, " ", line); cmd=cmd line
            }
            close("/proc/"pid"/cmdline")
            if (cmd=="") cmd="-"
        } else {
            pid="-"; cmd="-"
        }
        print_row(addr, pid, cmd)
    }'
}

show_ports
