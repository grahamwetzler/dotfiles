function venv
    # Quickly create a venv, activate, and update pip.
    python -m venv venv
    source ./venv/bin/activate.fish
    pip install --upgrade --quiet pip
end
