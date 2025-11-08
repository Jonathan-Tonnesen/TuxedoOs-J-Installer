import subprocess
from libcalamares.utils import debug, check_target_env_call


def ask_user():
    """
    Ask the user (graphically) if they want to install the AI suite.
    Tries kdialog first, then zenity. Returns True for Yes, False otherwise.
    """

    message = "Do you want to install the local AI suite (Ollama + Open WebUI)?"
    title = "AI Suite Installer"

    # Try kdialog (KDE)
    try:
        result = subprocess.run(
            ["kdialog", "--yesno", message, "--title", title],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if result.returncode == 0:
            return True
        # Non-zero means "No" or dialog closed
        return False
    except FileNotFoundError:
        pass

    # Fallback to zenity (GNOME-style dialog)
    try:
        result = subprocess.run(
            ["zenity", "--question", f"--title={title}", f"--text={message}"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return result.returncode == 0
    except FileNotFoundError:
        # No GUI tools available; be conservative and do nothing
        return False


def run():
    debug("jinstaller: asking user whether to install AI suite.")

    if not ask_user():
        debug("jinstaller: user chose not to install AI suite (or no dialog available).")
        return None

    debug("jinstaller: running /opt/jinstaller/install.sh inside target system.")
    check_target_env_call(["/usr/bin/bash", "/opt/jinstaller/install.sh"])
    return None

