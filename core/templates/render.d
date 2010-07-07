module templates.render;
import core;
import panel;
import lib;
import shared;

class TemplateJS : TemplateInterface {
	enum {
		LOAD,
		UNLOAD,
		BEFORE_UNLOAD
	}
	
	static private typeof(this)[string] instances;
	static this() {
		PNL.registerTemplate("js", &this.create);
		PNL.registerTemplate("endjs", &this.create);
	}

	static private void create(inout PNL pnl, string cmd, string inside) {
		if(!(pnl.name in instances)) {
			instances[pnl.name] = new typeof(this)(pnl, inside);
		}
		
		string[string] opts;
		
		opts.parse_options(inside);
		
		PNLByte* p = pnl.newByte();
		p.action = pnl_action_template;
		if(cmd == "js") {
			string* ptr_event = "event" in opts;
			if(ptr_event) {
				if(*ptr_event == "unload") {
					in_js = UNLOAD;
					p.dg = &instances[pnl.name].render_unload;
				} else if(*ptr_event == "beforeunload" || *ptr_event == "before_unload") {
					in_js = BEFORE_UNLOAD;
					p.dg = &instances[pnl.name].render_beforeunload;
				} else {
					debug errorln("sorry, the javascript event '", *ptr_event, "' doesn't exist");
				}
			} else {
				in_js = LOAD;
				p.dg = &instances[pnl.name].render_load;
			}
		} else if(cmd == "endjs") {
			switch(in_js) {
			default:
			case LOAD:
				p.dg = &instances[pnl.name].render_end_load;
				break;
			case UNLOAD:
				p.dg = &instances[pnl.name].render_end_unload;
				break;
			case BEFORE_UNLOAD:
				p.dg = &instances[pnl.name].render_end_beforeunload;
				break;
			}
			
			in_js = false;
		}
	}
	
	private string panel;
	private string js_after;
	
	static private size_t begin_ptr;
	static private size_t save_ptr;
	
	this(inout PNL pnl, string params) {
		this.panel = pnl.name; 
	}
	
	private void render_load() {
		begin_ptr = out_ptr;
	}
	
	private void render_end_load() {
		Core.js_out ~= out_tmp[begin_ptr .. out_ptr].dup;
		out_ptr = begin_ptr;
	}
	
	private void render_unload() {
		begin_ptr = out_ptr;
		prt("kernel.unload('");
		prt(panel);
		prt(`', "`);
		Core.js_out ~= out_tmp[begin_ptr .. out_ptr].dup;
		save_ptr = out_ptr;
	}
	
	private void render_end_unload() {
		auto js_out_ptr = Core.js_out.length;
		auto processed_ptr = js_out_ptr;
		auto len = out_ptr - save_ptr;
		Core.js_out.length = js_out_ptr + (len*2);
		
		for(auto i = save_ptr; i < out_ptr; i++) {
			if(out_tmp[i] == '\\') {
				Core.js_out[processed_ptr++] = '\\';
				Core.js_out[processed_ptr++] = '\\';
			} else if(out_tmp[i] == '"') {
				Core.js_out[processed_ptr++] = '\\';
				Core.js_out[processed_ptr++] = '"';
			} else {
				Core.js_out[processed_ptr++] = out_tmp[i];
			}
		}
		
		Core.js_out.length = processed_ptr;
		out_ptr = save_ptr + (processed_ptr - js_out_ptr); 
		
		Core.js_out ~= `");`;
		out_ptr = begin_ptr;
	}
	
	private void render_beforeunload() {
		errorln("not yet implemented...");
	}
	
	private void render_end_beforeunload() {
		errorln("not yet implemented...");
	}
}

class TemplateRender : TemplateInterface {
	static typeof(this)[] instances;
	static this() {
		PNL.registerTemplate("render", &this.create);
	}
	
	static private void create(inout PNL pnl, string cmd, string inside) {
		instances ~= new typeof(this)(pnl, inside);
		PNLByte* p = pnl.newByte();
		p.action = pnl_action_template;
		p.dg = &instances[$ - 1].render;
	}
	
	private string panel;
	private string div;
	
	this(inout PNL pnl, string params) {
		string[string] opts;
		string* val_div = "div" in opts;
		string* val_panel = "panel" in opts;
		
		opts.parse_options(params);
		
		if(val_div && val_panel) {
			panel = *val_panel;
			div = *val_div;
		} else {
			debug errorln("You must supply the template 'render' with a 'panel' and a 'div' field");
		}
	}
	
	void render() {
		PANELS[div] = panel;
	}
}

class TemplateImg : TemplateInterface {
	static typeof(this)[] instances;
	static this() {
		PNL.registerTemplate("img", &this.create);
	}
	
	static private void create(inout PNL pnl, string cmd, string inside) {
		instances ~= new typeof(this)(pnl, inside);
		PNLByte* p = pnl.newByte();
		p.action = pnl_action_template;
		p.dg = &instances[$ - 1].render;
	}
	
	private string prerender1;
	private string prerender2;
	private string* ptr_url;
	private char size;
	
	this(inout PNL pnl, string params) {
		string[string] opts;
		opts.parse_options(params);
		
		string* val_url = "url" in opts;
		string* val_size = "size" in opts;
		
		if(val_url && val_size) {
			string* val;
			string var = (*val_url)[1 .. $];
			int v_scope = pnl.find_var(var);
			if(v_scope >= 0 && pnl.var_type[v_scope][var] == pnl_action_var_str) {
				ptr_url = cast(string*)pnl.var_ptr[v_scope][var];
			} else {
				debug errorln("variable '", var, "' is not registered");
			}
			
			
			size = translate_photo_size(toUint(*val_size));
			if(size == 0) {
				debug errorln(*val_size, " is an invalid size");
			}
			
			
			val = "nohtml" in opts;
			if(!val) {
				prerender1 = "<img";
				
				
				val = "id" in opts;
				if(val) {
					prerender1 ~= ` id="` ~ *val ~ '"';
				}
				
				prerender1 ~= ` src="j/`;
				prerender2 = `"/>`;
			}
			
		} else {
			debug errorln("You must supply the 'img' template with a 'url' and a 'size' field");
		}
	}
	
	void render() {
		if(prerender1 != null) {
			prt(prerender1);
		}
		
		string url = (*ptr_url);
		if(url.length == 0) {
			url = "nf ".dup;
			url[2] = size;
		} else {
			url[PHOTO_OFFSET.SIZE] = size;
		}
		
		prt(url);
		
		if(prerender2 != null) {
			prt(prerender2);
		}
	}
}


class TemplateYouTube : TemplateInterface {
	static typeof(this)[] instances;
	static this() {
		PNL.registerTemplate("youtube", &this.create);
	}
	
	static private void create(inout PNL pnl, string cmd, string inside) {
		instances ~= new typeof(this)(pnl, inside);
		PNLByte* p = pnl.newByte();
		p.action = pnl_action_template;
		p.dg = &instances[$ - 1].render;
	}
	
	private string prerender;
	private string js;
	
	this(inout PNL pnl, string params) {
		string[string] opts;
		string* val;
		
		opts.parse_options(params);
		
		val = "vid" in opts;
		if(val) {
			string id = *val;
			if(id.length != 11) {
				debug errorln("You have entered an invalid YouTube id ", id);
			}
			
			prerender = `<p `;
			val = "class" in opts;
			if(val) {
				prerender ~= `class="` ~ *val ~ '"';
			} else {
				prerender ~= `class="video"`;
			}
			
			
			
			val = "id" in opts;
			if(val) {
				prerender ~= ` id="` ~ *val ~ '"';
			}
			
			string content = `><span id="ytxxxx">&nbsp;</span></p>`.dup;
			enum {
				offset1 = `><span id="yt`.length,
				offset2 = `showYoutube('yt`.length,
				offset3 = `showYoutube('ytxxxx','`.length,
			}
			
			string rand_id = rand_str(4);
			
			content[offset1 .. offset1 + 4] = rand_id[0 .. 4];
			prerender ~= content;
			
			js = `showYoutube('ytxxxx','xxxxxxxxxxx');`.dup;
			js[offset2 .. offset2 + 4] = rand_id;
			js[offset3 .. offset3 + 11] = id[0 .. 11];
		} else {
			debug errorln("You must supply the 'youtube' template with a 'vid' field");
		}
	}
	
	void render() {
		prt(prerender);
		Core.js_out ~= js;
	}
}

