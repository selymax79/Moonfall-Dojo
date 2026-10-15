## Browser-only presentation/lifecycle adapter. Never reads or advances gameplay/RNG.
extends Node

signal suspend_requested
signal availability_changed(unavailable: bool)
var touch_browser := false
var portrait := false
var unavailable := false
var callback: JavaScriptObject


func _ready() -> void:
	if not OS.has_feature("web"): return
	touch_browser = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0"))
	callback = JavaScriptBridge.create_callback(browser_changed)
	# The notice lives outside the letterboxed canvas so it remains readable in portrait.
	# One listener set per Main instance; scene replacement removes it before installing another.
	JavaScriptBridge.eval("""
	window.moonfallAttach = function(callback, touch) {
		const notice = document.createElement('div');
		notice.textContent = 'Rotate your device to landscape to play Moonfall Dojo.';
		notice.setAttribute('role', 'status');
		notice.id = 'moonfall-orientation';
		notice.style.cssText = 'position:fixed;inset:0;z-index:100;background:#080f1c;color:#f2d9a6;align-items:center;justify-content:center;text-align:center;padding:32px;font:24px system-ui;box-sizing:border-box';
		document.body.appendChild(notice);
		const update = () => {
			const portrait = touch && innerHeight > innerWidth;
			notice.style.display = portrait ? 'flex' : 'none';
			callback(portrait, document.hidden || !document.hasFocus());
		};
		window.addEventListener('resize', update);
		window.addEventListener('blur', update);
		window.addEventListener('focus', update);
		document.addEventListener('visibilitychange', update);
		window.moonfallDetach = () => {
			window.removeEventListener('resize', update);
			window.removeEventListener('blur', update);
			window.removeEventListener('focus', update);
			document.removeEventListener('visibilitychange', update);
			notice.remove();
		};
		update();
	};
	""", true)
	JavaScriptBridge.get_interface("window").moonfallAttach(callback, touch_browser)


func browser_changed(arguments: Array) -> void:
	portrait = bool(arguments[0])
	unavailable = portrait or bool(arguments[1])
	if unavailable: suspend_requested.emit()
	availability_changed.emit(unavailable)


func _exit_tree() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.moonfallDetach) window.moonfallDetach(); delete window.moonfallDetach; delete window.moonfallAttach;", true)
