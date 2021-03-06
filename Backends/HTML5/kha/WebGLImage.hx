package kha;

import haxe.io.Bytes;
import js.Browser;
import js.html.ImageElement;
import js.html.Uint8Array;
import js.html.VideoElement;
import js.html.webgl.GL;
import kha.graphics4.TextureFormat;
import kha.graphics4.DepthStencilFormat;
import kha.js.CanvasGraphics;
import kha.js.graphics4.Graphics;

class WebGLImage extends Image {
	public var image: Dynamic;
	public var video: VideoElement;

	private static var context: Dynamic;
	private var data: Dynamic;

	private var myWidth: Int;
	private var myHeight: Int;
	private var format: TextureFormat;
	private var renderTarget: Bool;
	public var frameBuffer: Dynamic;
	public var renderBuffer: Dynamic;
	public var texture: Dynamic;

	private var graphics1: kha.graphics1.Graphics;
	private var graphics2: kha.graphics2.Graphics;
	private var graphics4: kha.graphics4.Graphics;

	var depthStencilFormat: DepthStencilFormat;

	public static function init() {
		var canvas: Dynamic = Browser.document.createElement("canvas");
		if (canvas != null) {
			context = canvas.getContext("2d");
			canvas.width = 2048;
			canvas.height = 2048;
			context.globalCompositeOperation = "copy";
		}
	}

	public function new(width: Int, height: Int, format: TextureFormat, renderTarget: Bool, depthStencilFormat: DepthStencilFormat) {
		myWidth = width;
		myHeight = height;
		this.format = format;
		this.renderTarget = renderTarget;
		image = null;
		video = null;
		this.depthStencilFormat = depthStencilFormat;
		if (renderTarget) createTexture();
	}

	override private function get_g1(): kha.graphics1.Graphics {
		if (graphics1 == null) {
			graphics1 = new kha.graphics2.Graphics1(this);
		}
		return graphics1;
	}

	override private function get_g2(): kha.graphics2.Graphics {
		if (graphics2 == null) {
			graphics2 = new kha.js.graphics4.Graphics2(this);
		}
		return graphics2;
	}

	override private function get_g4(): kha.graphics4.Graphics {
		if (graphics4 == null) {
			graphics4 = new Graphics(this);
		}
		return graphics4;
	}

	override private function get_width(): Int {
		return myWidth;
	}

	override private function get_height(): Int {
		return myHeight;
	}

	override private function get_realWidth(): Int {
		return myWidth;
	}

	override private function get_realHeight(): Int {
		return myHeight;
	}

	override public function isOpaque(x: Int, y: Int): Bool {
		if (data == null) {
			if (context == null) return true;
			else createImageData();
		}
		return (data.data[y * Std.int(image.width) * 4 + x * 4 + 3] != 0);
	}

	override public function at(x: Int, y: Int): Color {
		if (data == null) {
			if (context == null) return Color.Black;
			else createImageData();
		}
		return Color.fromValue(data.data[y * Std.int(image.width) * 4 + x * 4 + 0]);
	}

	function createImageData() {
		context.strokeStyle = "rgba(0,0,0,0)";
		context.fillStyle = "rgba(0,0,0,0)";
		context.fillRect(0, 0, image.width, image.height);
		context.drawImage(image, 0, 0, image.width, image.height, 0, 0, image.width, image.height);
		data = context.getImageData(0, 0, image.width, image.height);
	}

	private static function upperPowerOfTwo(v: Int): Int {
		v--;
		v |= v >>> 1;
		v |= v >>> 2;
		v |= v >>> 4;
		v |= v >>> 8;
		v |= v >>> 16;
		v++;
		return v;
	}

	public function createTexture(): Void {
		if (SystemImpl.gl == null) return;
		texture = SystemImpl.gl.createTexture();
		//texture.image = image;
		SystemImpl.gl.bindTexture(GL.TEXTURE_2D, texture);
		//Sys.gl.pixelStorei(Sys.gl.UNPACK_FLIP_Y_WEBGL, true);

		SystemImpl.gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
		SystemImpl.gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
		SystemImpl.gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
		SystemImpl.gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
		if (renderTarget) {
			frameBuffer = SystemImpl.gl.createFramebuffer();
			SystemImpl.gl.bindFramebuffer(GL.FRAMEBUFFER, frameBuffer);
			switch (format) {
			case DEPTH16:
				SystemImpl.gl.texImage2D(GL.TEXTURE_2D, 0, GL.DEPTH_COMPONENT, realWidth, realHeight, 0, GL.DEPTH_COMPONENT, GL.UNSIGNED_SHORT, null);
			case RGBA128:
				SystemImpl.gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, realWidth, realHeight, 0, GL.RGBA, GL.FLOAT, null);
			case RGBA64:
				SystemImpl.gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, realWidth, realHeight, 0, GL.RGBA, SystemImpl.halfFloat.HALF_FLOAT_OES, null);
			case RGBA32:
				SystemImpl.gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, realWidth, realHeight, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);
			default:
				SystemImpl.gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, realWidth, realHeight, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);
			}
			
			if (format == DEPTH16) {
				SystemImpl.gl.framebufferTexture2D(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.TEXTURE_2D, texture, 0);
				// OSX/Linux WebGL implementations throw incomplete framebuffer error, create color attachment
				if (untyped __js__('navigator.appVersion.indexOf("Win")') == -1) {
					var colortex = SystemImpl.gl.createTexture();
					SystemImpl.gl.bindTexture(GL.TEXTURE_2D, colortex);
					SystemImpl.gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, realWidth, realHeight, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);
					SystemImpl.gl.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, colortex, 0);
					SystemImpl.gl.bindTexture(GL.TEXTURE_2D, texture);
				}
			}
			else {
				SystemImpl.gl.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, texture, 0);
			}

			switch (depthStencilFormat) {
				case NoDepthAndStencil: {}
				case DepthOnly: {
					renderBuffer = SystemImpl.gl.createRenderbuffer();
					SystemImpl.gl.bindRenderbuffer(GL.RENDERBUFFER, renderBuffer);
					SystemImpl.gl.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT16, realWidth, realHeight);
					SystemImpl.gl.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, renderBuffer);
				}
				case DepthAutoStencilAuto: 
					createDepthStencilBuffer();
				case Depth24Stencil8:
					createDepthStencilBuffer();
				case Depth32Stencil8:
					createDepthStencilBuffer();
			}

			SystemImpl.gl.bindRenderbuffer(GL.RENDERBUFFER, null);
			SystemImpl.gl.bindFramebuffer(GL.FRAMEBUFFER, null);
		}
		else if (video != null) {
			SystemImpl.gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, GL.RGBA, GL.UNSIGNED_BYTE, video);
		}
		else {
			switch (format) {
			case RGBA128:
				SystemImpl.gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, myWidth, myHeight, 0, GL.RGBA, GL.FLOAT, image);
			case RGBA64:
				SystemImpl.gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, myWidth, myHeight, 0, GL.RGBA, SystemImpl.halfFloat.HALF_FLOAT_OES, image);
			case RGBA32:
				SystemImpl.gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, GL.RGBA, GL.UNSIGNED_BYTE, image);
			default:
				SystemImpl.gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, GL.RGBA, GL.UNSIGNED_BYTE, image);
			}
		}
		SystemImpl.gl.bindTexture(GL.TEXTURE_2D, null);
	}

	function createDepthStencilBuffer() {
		renderBuffer = SystemImpl.gl.createRenderbuffer();
		SystemImpl.gl.bindRenderbuffer(GL.RENDERBUFFER, renderBuffer);
		SystemImpl.gl.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_STENCIL, realWidth, realHeight);
		SystemImpl.gl.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_STENCIL_ATTACHMENT, GL.RENDERBUFFER, renderBuffer);
	}

	public function set(stage: Int): Void {
		SystemImpl.gl.activeTexture(GL.TEXTURE0 + stage);
		SystemImpl.gl.bindTexture(GL.TEXTURE_2D, texture);
		if (video != null) SystemImpl.gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, GL.RGBA, GL.UNSIGNED_BYTE, video);
	}

	public var bytes: Bytes;

	override public function lock(level: Int = 0): Bytes {
		bytes = Bytes.alloc(format == TextureFormat.RGBA32 ? 4 * width * height : (format == TextureFormat.RGBA128 ? 16 * width * height : width * height));
		return bytes;
	}

	override public function unlock(): Void {
		if (SystemImpl.gl != null) {
			texture = SystemImpl.gl.createTexture();
			//texture.image = image;
			SystemImpl.gl.bindTexture(GL.TEXTURE_2D, texture);
			//Sys.gl.pixelStorei(Sys.gl.UNPACK_FLIP_Y_WEBGL, true);

			SystemImpl.gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
			SystemImpl.gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
			SystemImpl.gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
			SystemImpl.gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);

			switch (format) {
			case L8:
				SystemImpl.gl.texImage2D(GL.TEXTURE_2D, 0, GL.LUMINANCE, width, height, 0, GL.LUMINANCE, GL.UNSIGNED_BYTE, new Uint8Array(bytes.getData()));

				if (SystemImpl.gl.getError() == 1282) { // no LUMINANCE support in IE11
					var rgbaBytes = Bytes.alloc(width * height * 4);
					for (y in 0...height) for (x in 0...width) {
						var value = bytes.get(y * width + x);
						rgbaBytes.set(y * width * 4 + x * 4 + 0, value);
						rgbaBytes.set(y * width * 4 + x * 4 + 1, value);
						rgbaBytes.set(y * width * 4 + x * 4 + 2, value);
						rgbaBytes.set(y * width * 4 + x * 4 + 3, 255);
					}
					SystemImpl.gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, width, height, 0, GL.RGBA, GL.UNSIGNED_BYTE, new Uint8Array(rgbaBytes.getData()));
				}
			case RGBA128:
				SystemImpl.gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, width, height, 0, GL.RGBA, GL.FLOAT, new Uint8Array(bytes.getData()));
			case RGBA32:
				SystemImpl.gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, width, height, 0, GL.RGBA, GL.UNSIGNED_BYTE, new Uint8Array(bytes.getData()));
			default:
				SystemImpl.gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, width, height, 0, GL.RGBA, GL.UNSIGNED_BYTE, new Uint8Array(bytes.getData()));
			}

			SystemImpl.gl.bindTexture(GL.TEXTURE_2D, null);
			bytes = null;
		}
	}

	override public function unload(): Void {

	}

	override public function generateMipmaps(levels: Int): Void {
		// WebGL requires to generate all mipmaps down to 1x1 size, ignoring levels for now
		SystemImpl.gl.bindTexture(GL.TEXTURE_2D, texture);
		SystemImpl.gl.generateMipmap(GL.TEXTURE_2D);
	}

	override public function setMipmaps(mipmaps: Array<Image>): Void {
		// Similar to generateMipmaps, specify all the levels down to 1x1 size
		SystemImpl.gl.bindTexture(GL.TEXTURE_2D, texture);
		if (format != TextureFormat.RGBA32) {
			for (i in 0...mipmaps.length) {
				SystemImpl.gl.texImage2D(GL.TEXTURE_2D, i + 1, GL.RGBA, mipmaps[i].width, mipmaps[i].height, 0, GL.RGBA, format == TextureFormat.RGBA128 ? GL.FLOAT : SystemImpl.halfFloat.HALF_FLOAT_OES, cast(mipmaps[i], WebGLImage).image);
			}
		}
		else {
			for (i in 0...mipmaps.length) {
				SystemImpl.gl.texImage2D(GL.TEXTURE_2D, i + 1, GL.RGBA, GL.RGBA, GL.UNSIGNED_BYTE, cast(mipmaps[i], WebGLImage).image);
			}
		}
	}
}
