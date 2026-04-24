function penv
    # --- Help mode ---
    if test "$argv[1]" = "-h" -o "$argv[1]" = "--help"
        echo "Usage: penv [options] [env_name]"
        echo ""
        echo "Automatically creates and activates a pyenv virtual environment."
        echo "If no env_name is provided, it uses the current directory name appended with '_env'."
        echo ""
        echo "Options:"
        echo "  -h, --help           Show this help message and exit"
        echo "  -l, --list           List all virtual environments"
        echo "  -lv, --list-versions List installed base Python versions"
        echo "  -d <env_name>        Delete the specified virtual environment"
        echo "  -x, --deactivate     Deactivate the current environment (or use 'penvd')"
        echo "  -C, --clear-envs     Delete ALL virtual environments"
        echo "  -V, --clear-versions Delete ALL installed base Python versions"
        echo "  -i, --install <ver>  Install a specific Python version"
        echo "  -g, --global <ver>   Set the global Python version"
        echo "  -s, --set-local      Set the local Python version to the active environment"
        return 0
    end

    # --- List mode ---
    if test "$argv[1]" = "-l" -o "$argv[1]" = "--list"
        pyenv virtualenvs
        return 0
    end

    # --- List versions mode ---
    if test "$argv[1]" = "-lv" -o "$argv[1]" = "--list-versions"
        echo "Installed Base Python Versions:"
        set VERSIONS (pyenv versions --bare | grep -v '_env$' | grep -E '^[0-9]')
        for ver in $VERSIONS
            echo "  - $ver"
        end
        return 0
    end

    # --- Deactivate mode ---
    if test "$argv[1]" = "-x" -o "$argv[1]" = "--deactivate"
        penvd
        return 0
    end

    # --- Delete mode ---
    if test "$argv[1]" = "-d"
        if test -z "$argv[2]"
            echo "❌ Usage: penv -d <env_name>"
            return 1
        end
        set ENV_NAME "$argv[2]_env"
        if pyenv virtualenvs --bare | grep -qx -- "$ENV_NAME"
            read -P "Are you sure you want to delete '$ENV_NAME'? (y/n) " -n 1 choice
            echo
            if string match -qr '^[Yy]$' -- $choice
                pyenv uninstall -f "$ENV_NAME"
                echo "✅ Virtual environment '$ENV_NAME' deleted"
            else
                echo "❎ Aborted"
            end
        else
            echo "⚠️ No such environment: $ENV_NAME"
        end
        return 0
    end

    # --- Set local mode ---
    if test "$argv[1]" = "-s" -o "$argv[1]" = "--set-local"
        set ENV_TO_SET "$argv[2]"
        if test -z "$ENV_TO_SET"
            set ENV_TO_SET (pyenv version-name)
            if test "$ENV_TO_SET" = "system"
                echo "⚠️ No pyenv environment active. Specify an environment or activate one first."
                return 1
            end
        end
        if not string match -qr '_env$' -- "$ENV_TO_SET"
            if not pyenv virtualenvs --bare | grep -qx -- "$ENV_TO_SET"
                if pyenv virtualenvs --bare | grep -qx -- "${ENV_TO_SET}_env"
                    set ENV_TO_SET "${ENV_TO_SET}_env"
                end
            end
        end
        echo "Setting local pyenv version to '$ENV_TO_SET' in current directory..."
        pyenv local "$ENV_TO_SET"
        echo "✅ Local version set."
        return 0
    end

    # --- Clear envs mode ---
    if test "$argv[1]" = "-C" -o "$argv[1]" = "--clear-envs"
        set ENVS (pyenv virtualenvs --bare | grep '_env$')
        if test -z "$ENVS"
            echo "No virtual environments found."
            return 0
        end
        echo "The following virtual environments will be DELETED:"
        for env in $ENVS
            echo "  - $env"
        end
        read -P "Are you sure? (y/n) " -n 1 choice
        echo
        if string match -qr '^[Yy]$' -- "$choice"
            for env in $ENVS
                pyenv uninstall -f "$env"
            end
            echo "✅ All virtual environments deleted."
        else
            echo "❎ Aborted"
        end
        return 0
    end

    # --- Clear versions mode ---
    if test "$argv[1]" = "-V" -o "$argv[1]" = "--clear-versions"
        set VERSIONS (pyenv versions --bare | grep -v '_env$' | grep -E '^[0-9]')
        if test -z "$VERSIONS"
            echo "No base Python versions found."
            return 0
        end
        echo "The following base Python versions will be DELETED:"
        for ver in $VERSIONS
            echo "  - $ver"
        end
        read -P "Are you sure? (y/n) " -n 1 choice
        echo
        if string match -qr '^[Yy]$' -- "$choice"
            for ver in $VERSIONS
                pyenv uninstall -f "$ver"
            end
            echo "✅ All base Python versions deleted."
        else
            echo "❎ Aborted"
        end
        return 0
    end

    # --- Install mode ---
    if test "$argv[1]" = "-i" -o "$argv[1]" = "--install"
        if test -z "$argv[2]"
            echo "❌ Usage: penv -i <version>"
            return 1
        end
        echo "Installing Python $argv[2]..."
        pyenv install "$argv[2]"
        return 0
    end

    # --- Global mode ---
    if test "$argv[1]" = "-g" -o "$argv[1]" = "--global"
        if test -z "$argv[2]"
            echo "❌ Usage: penv -g <version>"
            return 1
        end
        echo "Setting global Python version to $argv[2]..."
        pyenv global "$argv[2]"
        return 0
    end

    # --- Env name from arg or current dir ---
    if test -n "$argv[1]"
        set ENV_NAME "$argv[1]_env"
    else
        set ENV_NAME (basename $PWD)_env
    end

    # --- Already active? ---
    if test "$PYENV_VERSION" = "$ENV_NAME"
        echo "⚡ '$ENV_NAME' is already active"
        echo "Current Python: "(pyenv which python)
        return 0
    end

    # --- Deactivate any active env ---
    if test -n "$PYENV_VERSION"
        pyenv deactivate
        echo "Deactivated '$PYENV_VERSION'"
    end

    # --- Detect local Python version or fallback ---
    set LOCAL_VERSION (pyenv local 2>/dev/null; or echo "")
    if test -n "$LOCAL_VERSION"
        set PY_VERSION "$LOCAL_VERSION"
    else
        # Fetch installed base versions
        set BASE_VERSIONS (pyenv versions --bare | grep -v '_env$' | grep -E '^[0-9]')
        set NUM_VERSIONS (count $BASE_VERSIONS)
        
        if test $NUM_VERSIONS -eq 0
            set PY_VERSION "3.10.12"
            echo "⚠️ No base Python versions installed. Defaulting to $PY_VERSION."
        else if test $NUM_VERSIONS -eq 1
            set PY_VERSION $BASE_VERSIONS[1]
        else
            # Interactive selection only if we need to create it
            if not pyenv virtualenvs --bare | grep -qx -- "$ENV_NAME"
                echo "Multiple Python versions found. Which one would you like to use for '$ENV_NAME'?"
                for i in (seq 1 $NUM_VERSIONS)
                    echo "  [$i] "$BASE_VERSIONS[$i]
                end
                read -P "Select a version (1-$NUM_VERSIONS) [default: global]: " choice
                
                if string match -qr '^[0-9]+$' -- "$choice"
                    if test "$choice" -ge 1 -a "$choice" -le "$NUM_VERSIONS"
                        set PY_VERSION $BASE_VERSIONS[$choice]
                    else
                        set PY_VERSION (pyenv global 2>/dev/null | head -n 1; or echo "")
                        if test -z "$PY_VERSION" -o "$PY_VERSION" = "system"
                            set PY_VERSION $BASE_VERSIONS[1]
                        end
                        echo "Using default: $PY_VERSION"
                    end
                else
                    set PY_VERSION (pyenv global 2>/dev/null | head -n 1; or echo "")
                    if test -z "$PY_VERSION" -o "$PY_VERSION" = "system"
                        set PY_VERSION $BASE_VERSIONS[1]
                    end
                    echo "Using default: $PY_VERSION"
                end
            else
                set PY_VERSION (pyenv global 2>/dev/null | head -n 1; or echo "")
            end
        end
    end

    # --- Create env if missing ---
    if not pyenv virtualenvs --bare | grep -qx -- "$ENV_NAME"
        echo "Creating new environment '$ENV_NAME' with Python $PY_VERSION"
        pyenv virtualenv "$PY_VERSION" "$ENV_NAME"
    else
        echo "Virtual environment '$ENV_NAME' already exists"
    end

    # --- Activate ---
    pyenv activate "$ENV_NAME"
    echo "✅ Activated '$ENV_NAME'"
    echo "Current Python: "(pyenv which python)
end
