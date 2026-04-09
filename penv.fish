function penv
    # --- Delete mode ---
    if test "$argv[1]" = "-d"
        if test -z "$argv[2]"
            echo "❌ Usage: penv -d <env_name>"
            return 1
        end
        set ENV_NAME "$argv[2]_env"
        if pyenv virtualenvs --bare | grep -qx "$ENV_NAME"
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
        set PY_VERSION "3.10.12"
    end

    # --- Create env if missing ---
    if not pyenv virtualenvs --bare | grep -qx "$ENV_NAME"
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
