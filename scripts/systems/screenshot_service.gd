class_name ScreenshotService
extends RefCounted

const FILE_PREFIX := "roguelike_mcp"

static func capture(viewport: Viewport) -> Image:
	return viewport.get_texture().get_image()

## Saves the image to disk (native) or triggers a browser download (web).
## Returns the saved file path, or "" on web / on failure.
static func download(image: Image) -> String:
	if OS.has_feature("web"):
		_web_download(image)
		return ""
	return _save_to_disk(image)

## Opens the OS share/open-with chooser (native) or the Web Share sheet (web).
static func share(image: Image) -> String:
	if OS.has_feature("web"):
		_web_share(image)
		return ""
	var path := _save_to_disk(image)
	if path != "":
		OS.shell_open(path)
	return path

static func _save_to_disk(image: Image) -> String:
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if dir == "":
		dir = OS.get_user_data_dir()
	var filename := "%s_%s.png" % [FILE_PREFIX, Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")]
	var path := dir.path_join(filename)
	if image.save_png(path) != OK:
		return ""
	return path

static func _image_base64(image: Image) -> String:
	return Marshalls.raw_to_base64(image.save_png_to_buffer())

static func _web_download(image: Image) -> void:
	var js := """
	(function() {
		var bytes = atob('%s');
		var arr = new Uint8Array(bytes.length);
		for (var i = 0; i < bytes.length; i++) { arr[i] = bytes.charCodeAt(i); }
		var blob = new Blob([arr], {type: 'image/png'});
		var a = document.createElement('a');
		a.href = URL.createObjectURL(blob);
		a.download = '%s.png';
		document.body.appendChild(a);
		a.click();
		document.body.removeChild(a);
	})();
	""" % [_image_base64(image), FILE_PREFIX]
	JavaScriptBridge.eval(js, true)

static func _web_share(image: Image) -> void:
	var js := """
	(function() {
		var bytes = atob('%s');
		var arr = new Uint8Array(bytes.length);
		for (var i = 0; i < bytes.length; i++) { arr[i] = bytes.charCodeAt(i); }
		var file = new File([arr], '%s.png', {type: 'image/png'});
		if (navigator.canShare && navigator.canShare({files: [file]})) {
			navigator.share({files: [file], title: 'My Roguelike Run'});
		} else {
			var a = document.createElement('a');
			a.href = URL.createObjectURL(file);
			a.download = '%s.png';
			document.body.appendChild(a);
			a.click();
			document.body.removeChild(a);
		}
	})();
	""" % [_image_base64(image), FILE_PREFIX, FILE_PREFIX]
	JavaScriptBridge.eval(js, true)
