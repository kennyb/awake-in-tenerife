module templates.textbox;
import core;
import panel;
import lib;
import shared;

/*class TemplateSubmitButton {
	static typeof(this)[] instances;
	static this() {
		PNL.registerTemplate("submit", &this.create);
	}
	
	static void create(inout PNL pnl, string cmd, string inside) {
		instances ~= new typeof(this)(pnl, inside);
		PNLByte* p = pnl.newByte();
		p.action = pnl_action_template;
		p.dg = &instances[$ - 1].render;
	}

	string* ptr_value;
	size_t value_loc;
	size_t value_end_loc;
	string prerender;
	
	this(inout PNL pnl, string params) {
		string text;
		string clicked_text;
		string css_class;
		string id;
		string name;
		string style;
		string* val;
		
		string[string] opts;
		opts.parse_options(params);
		
		val = "text" in opts;
		if(val) {
			text = *val;
			assert(text.length > 1);
			if(text[0] == '$') {
				string var = text[1 .. $];
				int v_scope = pnl.find_var(var, scope_level);
				if(v_scope >= 0) {
					if(pnl.var_type[v_scope][var] == pnl_action_var_str) {
						ptr_value = cast(string*)pnl.var_ptr[v_scope][var];
						text = null;
					}
				} else {
					debug errorln("variable '", var, "' is not registered");
				}
			}
		} else {
			text = "Submit";
		}
		
		val = "clicked_text" in opts;
		if(val) {
			clicked_text = *val;
			assert(clicked_text.length > 1);
			if(clicked_text[0] == '$') {
				string var = clicked_text[1 .. $];
				int v_scope = pnl.find_var(var, scope_level);
				if(v_scope >= 0) {
					if(pnl.var_type[v_scope][var] == pnl_action_var_str) {
						ptr_value = cast(string*)pnl.var_ptr[v_scope][var];
						clicked_text = null;
					}
				} else {
					debug errorln("variable '", var, "' is not registered");
				}
			}
		} else {
			clicked_text = "Submit";
		}
		
		val = "class" in opts;
		if(val) {
			css_class = *val;
		}
		
		val = "id" in opts;
		if(val) {
			id = *val;
		}
		
		val = "style" in opts;
		if(val) {
			style = css_optimizer(*val);
		}
		
		// this has to be split because gdc doesn't like me otherwise :(
		prerender ~= `<input type="submit"`
			(css_class.length ? " class="` ~ css_class ~ '"' : null);
		prerender ~= 
			(id.length ? ` id="` ~ id ~ '"' : null) ~
			(style.length ? ` style="` ~ style ~ '"' : null) ;
		prerender ~= 
		` onclick="this.disabled = 'disabled'" value="` ~ (value.length && !ptr_value ?  value : default_text) ~ `"/>`;
		
		value_loc = find_s(prerender, ` value="`)+8;
		value_end_loc = value_loc + default_text.length;
	}
	
	void render() {
		if(ptr_value && (*ptr_value).length) {
			prt(prerender[0 .. value_loc]);
			prt(*ptr_value);
			prt(prerender[value_end_loc .. $]);
		} else {
			prt(prerender);
		}
	}
}*/

class TemplateTArea : TemplateTBox {
	private static typeof(this)[] instances;
	static this() {
		PNL.registerTemplate("textarea", &this.create);
	}
	
	private static void create(inout PNL pnl, string cmd, string inside) {
		instances ~= new typeof(this)(pnl, inside);
		PNLByte* p = pnl.newByte();
		p.action = pnl_action_template;
		p.dg = &instances[$ - 1].render;
	}
	
	this(inout PNL pnl, string params) {
		super(pnl, params);
		
		string prerender2 = prerender[value_end_loc+1 .. $];
		prerender = prerender[0 .. value_loc-8];
		
		string* val;
		string value;
		string default_text;
		string rows;
		string cols;
		string[string] opts;
		
		opts.parse_options(params);
		
		if(!ptr_value) {
			val = "value" in opts;
			if(val) {
				value = *val;
			}
		}
		
		val = "default_text" in opts;
		if(val) {
			default_text = *val;
		}
		
		val = "rows" in opts;
		if(val) {
			rows = *val;
		} else {
			rows = "7";
		}

		val = "cols" in opts;
		if(val) {
			cols = *val;
		} else {
			cols = "76";
		}
		
		//TODO!!!! - this definitely wack...
		val = "size_limit" in opts;
		if(!val) {
			opts["size_limit"] = "2600";
		}
		
		prerender = replace_ss(prerender, `<input type="text"`, "<textarea");
		prerender = replace_ss(prerender, `<input type="password"`, "<textarea");
		
		prerender ~= ` rows="` ~ rows ~ `" cols="` ~ cols ~ `" >`;
		value_loc = prerender.length;
		prerender ~= (value.length && !ptr_value ? value : default_text) ~ "</textarea>";
		value_end_loc = prerender.length - "</textarea>".length;
	}
}

class TemplateTBox {
	private static typeof(this)[] instances;
	static this() {
		PNL.registerTemplate("textbox", &this.create);
		PNL.registerTemplate("autofill", &this.create);
	}
	
	private static void create(inout PNL pnl, string cmd, string inside) {
		instances ~= new typeof(this)(pnl, inside);
		PNLByte* p = pnl.newByte();
		p.action = pnl_action_template;
		p.dg = &instances[$ - 1].render;
	}

	private string* ptr_value;
	private size_t value_loc;
	private size_t value_end_loc;
	private string prerender;
	
	this(inout PNL pnl, string params) {
		string type;
		string active_class;
		string inactive_class;
		string focus_class;
		string value;
		string click;
		string default_text;
		string id;
		string name;
		string style;
		string size_limit;
		string focus, blur, change, keypress, keydown, keyup, input;
		string autocomplete;		
		
		string[string] opts;
		string* val;
		
		opts.parse_options(params);
		
		val = "type" in opts;
		if(val && *val == "password") {
			type = "password";
		} else {
			type = "text";
		}
		
		val = "active_class" in opts;
		if(val) {
			active_class = *val;
		} else {
			active_class = "form-active";
		}
		
		val = "class" in opts;
		if(val) {
			inactive_class = *val;
		} else {
			inactive_class = "form";
		}
		
		val = "focus_class" in opts;
		if(value) {
			focus_class = *val;
		} else {
			focus_class = active_class;
		}
		
		val = "value" in opts;
		if(val) {
			value = *val;
			assert(value.length > 1);
			if(value[0] == '$' && value.length > 1) {
				string var = value[1 .. $];
				int v_scope = pnl.find_var(var);
				if(v_scope >= 0) {
					if(pnl.var_type[v_scope][var] == pnl_action_var_str) {
						ptr_value = cast(string*)pnl.var_str[v_scope][var];
						value = null;
					}
				} else {
					debug errorln("variable '", var, "' is not registered");
				}
			}
		}
		
		val = "default_text" in opts;
		if(val) {
			default_text = *val;
		}
		
		val = "id" in opts;
		if(val) {
			id = *val;
		}
		
		val = "onfocus" in opts;
		if(val) {
			focus = *val;
		}
		
		val = "onblur" in opts;
		if(val) {
			blur = *val;
		}
		
		val = "onchange" in opts;
		if(val) {
			change = *val;
		}
		
		val = "onkeydown" in opts;
		if(val) {
			keydown = *val;
		}
		
		val = "onkeypress" in opts;
		if(val) {
			keypress = *val;
		}
		
		val = "onkeyup" in opts;
		if(val) {
			keyup = *val;
		}
		
		val = "oninput" in opts;
		if(val) {
			input = *val;
		}
		
		val = "autocomplete" in opts;
		if(val) {
			autocomplete = *val;
		}
		
		val = "name" in opts;
		if(val) {
			name = *val;
		} else {
			debug stdoutln("You MUST have a name for your TBox!");
		}
		
		val = "click" in opts;
		if(val) {
			click = *val;
		}
		
		val = "style" in opts;
		if(val) {
			style = css_optimizer(*val);
		}
		
		val = "size_limit" in opts;
		if(val) {
			size_limit = *val;
		} else {
			size_limit = "100";
		}
		
		val = "autofill" in opts;
		if(val) {
			if(!id.length) {
				id = name;
			}
			
			if(!autocomplete.length) {
				autocomplete = "off";
			}
			
			//TODO! - add a check to make sure that the autofilled panel actually exists
			
			blur ~= "hide('ai" ~ id ~ "');hide('af" ~ id ~ "');";
			keyup ~= "af(event, '" ~ *val ~ "');";
			
			val = "autofill_class" in opts;
			if(val) {
				focus ~= "prepare_autofill(this, 'default text', '" ~ *val ~ "');";
			} else {
				focus ~= "prepare_autofill(this, 'default text');";
			}
			
		}
		
		// this has to be split because gdc doesn't like me otherwise :(
		prerender ~= `<div style="display:none" id="d_`;
		if(in_func) {
			prerender ~= "f_";
		}
		
		prerender ~= name ~ `">` ~ default_text ~ `</div><input type="` ~ type ~
			`" class="` ~ (value.length && !ptr_value ? active_class : inactive_class) ~
			`" name="`;
		if(in_func) {
			prerender ~= "f_";
		}
		
		prerender ~= name ~ '"';
		if(id.length) {
			prerender ~= ` id="` ~ id ~ '"';
		}
		
		if(style.length) {
			prerender ~= ` style="` ~ style ~ '"';
		}
		
		prerender ~= ` onfocus="tb(this,'focus','` ~ focus_class ~ "')";
		if(focus.length) {
			prerender ~= ';' ~ focus;
		}
		
		prerender ~= `" onblur="tb(this,'blur','` ~ active_class ~ "','" ~ inactive_class ~ '\'';
		if(click.length) {
			prerender ~= ",'" ~ click ~ '\'';
		}
		
		prerender ~= ')';
		if(blur.length) {
			prerender ~= ';' ~ blur;
		}
		
		prerender ~= `" onchange="tb(this,'change')`;
		if(change.length) {
			prerender ~= ';' ~ change;
		}
		prerender ~= '"';
		if(keypress.length) {
			prerender ~= ` onkeypress="` ~ keypress ~ '"';
		}
		
		if(keyup.length) {
			prerender ~= ` onkeyup="` ~ keyup ~ '"';
		}
		
		if(input.length) {
			prerender ~= ` oninput="` ~ input ~ '"';
		}
		
		if(autocomplete.length) {
			prerender ~= ` autocomplete="` ~ autocomplete ~ '"';
		}
		
		prerender ~= ` onkeydown="tb(this,'limit',` ~ size_limit ~ ')';
		
		if(keydown.length) {
			prerender ~= ';' ~ keydown;
		}
		
		prerender ~= `" value="` ~ (value.length && !ptr_value ?  value : default_text) ~ `" />`;
		
		value_loc = find_s(prerender, ` value="`)+8;
		value_end_loc = value_loc + default_text.length;
	}
	
	private void render() {
		if(ptr_value && (*ptr_value).length) {
			prt(prerender[0 .. value_loc]);
			prt(*ptr_value);
			prt(prerender[value_end_loc .. $]);
		} else {
			prt(prerender);
		}
	}
}

