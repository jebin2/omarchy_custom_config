function penvd
    if test -n "$PYENV_VERSION"
        echo "Deactivating '$PYENV_VERSION'..."
        pyenv deactivate
        echo "✅ Deactivated"
    else
        echo "⚠️ No active pyenv environment"
    end
end
