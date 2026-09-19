//@ pragma Env QT_QUICK_BACKEND=software
import Quickshell
import "host"

LockScreen {
    validationOnly: ["1", "visual"].includes(Quickshell.env("QUICKSHELL_LOCK_VALIDATE_ONLY"))
    visualValidation: Quickshell.env("QUICKSHELL_LOCK_VALIDATE_ONLY") === "visual"
}