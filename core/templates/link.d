module templates.link;

import core;
import panel;
import lib;
import shared;

class TemplateLink {
	import Integer = tango.text.convert.Integer;
	
	static typeof(this)[] instances;
	static this() {
		PNL.registerTemplate("link", &this.create);
		PNL.registerTemplate("endlink", &this.create);
	}
	
	static private void create(inout PNL pnl, string cmd, string inside) {
		if(cmd == "link") {
			instances ~= new typeof(this)(pnl, inside);
			PNLByte* p = pnl.newByte();
			p.action = pnl_action_template;
			p.dg = &instances[$ - 1].render;
		} else if(cmd == "endlink" || cmd == "/link") {
			//OPTIMIZE!! - optimization pass that goes through and gets all of the text in the file combines it into one big file, then adds the contants as well, to save bytes in panel text and also in having to rener constants.
			PNLByte* p = pnl.newByte();
			p.action = pnl_action_var_literal_str;
			p.ptr_str = pnl.getConst("</a>");
			in_func = false;
		}
	}
	
	this(inout PNL pnl, string params, bool ignore = false) {
		string rpc_link;
		string href;
		string func_href;
		
		var_type = null;
		// I do a lot of array appends ... preallocate the memory.
		rpc_link.length = 100;
		rpc_link.length = 0;
		
		uint arg_count = 0;
		uint func_arg_count = 0;
		string[string] link_opts;
		string[string] panels;
		string[string] args;
		string[string] func_args;
		string func;
		string custom_class;
		string custom_id;
		string custom_style;
		string onclick;
		
		uint[] func_var_type;
		char*[] func_variable;
		string*[] func_variable_str;
		uint[] func_var_loc;
		
		uint[] href_var_type;
		char*[] href_variable;
		string*[] href_variable_str;
		uint[] href_var_loc;
		
		ulong ivar;
		ulong istr;
		
		link_opts.parse_options(params);
		
		string* val;
		val = "panels" in link_opts;
		if(val) {
			if((*val)[0] == '{') {
				panels.parse_options(*val);
			} else {
				size_t loc = find(*val, ':');
				if(loc != -1) {
					panels[(*val)[0 .. loc]] = (*val)[loc+1 .. $];
				}
			}
		}
		
		val = "args" in link_opts;
		if(val && (*val)[0] == '{') {
			args.parse_options(*val);
		}
		
		val = "func" in link_opts;
		if(val) {
			func = *val;
			in_func = true;
			val = "func_args" in link_opts;
			if(val && (*val)[0] == '{') {
				func_args.parse_options(*val);
			}
		}
		
		string behaviour;
		val = "behaviour" in link_opts;
		if(val) {
			behaviour = *val;
		}
		
		string rpc_panels;
		string normal_panels;
		string panel_list;
		bool is_button;
		if(!in_js) {
			is_button = ("button" in link_opts ? true : false);
			if(is_button) {
				rpc_link = `<input type="button" onclick="`;
			} else {
				rpc_link = `<a onclick="`;
			}
			
			val = "onclick" in link_opts;
			if(val) {
				onclick = *val;
			}
			
			if(onclick.length) {
				rpc_link ~= (onclick[$-1] == ';' ? onclick : onclick ~ ';');
			}
			
			rpc_link ~= "return z('";
		} else {
			rpc_link = "z('";
		}
		
		if(panels.length) {
			uint j = 0;
			foreach(string key, string value; panels) {
				if(j++ != 0) {
					panel_list ~= ',';
				}
				
				panel_list ~= key ~ ':' ~ value;
			}
		}
		
		rpc_link ~= panel_list ~ '\'';
		
		foreach(string key, string value; args) {
			if(value[0] == '$') {
				string var = value[1 .. $];
				int v_scope = pnl.find_var(var);
				if(v_scope >= 0) {
					if(arg_count++) {
						href ~= '&';
					}
					
					href ~= key ~ '=';
					uint v_type = pnl.var_type[v_scope][var];
					href_var_type ~= v_type;
					if(v_type == pnl_action_var_str) {
						href_variable_str ~= pnl.var_str[v_scope][var];
					} else {
						href_variable ~= pnl.var_ptr[v_scope][var];
					}
					
					href_var_loc ~= href.length;
				} else {
					debug errorln("variable '", var, "' is not registered");
				}
			} else {
				if(arg_count++) {
					href ~= '&';
				}
				
				href ~= key ~ '=' ~ uri_encode(value);
			}
		}
		
		if(href.length || func.length) {
			rpc_link ~= ",'";
			
			ivar = 0;
			istr = 0;
			for(uint i = 0; i < href_var_type.length; i++) {
				uint v_type = href_var_type[i];
				if(v_type == pnl_action_var_str) {
					variable_str ~= href_variable_str[istr++];
				} else {
					variable ~= href_variable[ivar++];
				}
				
				var_type ~= v_type;
				var_loc ~= href_var_loc[i] + rpc_link.length;
			}
			
			rpc_link ~= href ~ '\'';
		}
		
		if(func.length || behaviour.length) {
			bool found_func = false;
			string[] fargs;
			if(ignore == false) {
				if(func in PNL.funcs) {
					found_func = true;
					if(func in PNL.func_args) {
						fargs = PNL.func_args[func];
					}
				} else if(func.length) {
					pnl.inlineError("you are calling function: '"~ func ~ "' which doesn't exist, or is not registered");
				}
			}
			
			rpc_link ~= ",'" ~ func ~ '\'';
			foreach(string key, string value; func_args) {
				if(found_func) {
					for(uint i = 0; i < fargs.length; i++) {
						if(fargs[i] == key) {
							fargs = fargs[0 .. i] ~ fargs[i+1 .. $];
						}
					}
				}
				
				if(value[0] == '$') {
					string var = value[1 .. $];
					int v_scope = pnl.find_var(var);
					if(v_scope >= 0) {
						if(func_arg_count++) {
							func_href ~= '&';
						}
						
						func_href ~= "f_" ~ key ~ '=';
						uint v_type = pnl.var_type[v_scope][var];
						func_var_type ~= v_type;
						
						// TODO!!!! - broken!
						if(v_type == pnl_action_var_str) {
							func_variable_str ~= pnl.var_str[v_scope][var];
						} else {
							func_variable ~= pnl.var_ptr[v_scope][var];
						}
						
						func_var_loc ~= func_href.length;
					} else {
						pnl.inlineError("variable '" ~ var ~ "' is not registered");
					}
				} else {
					if(func_arg_count++) {
						func_href ~= '&';
					}
					
					func_href ~= "f_" ~ key ~ '=' ~ uri_encode(value);
				}
			}
			
			if(found_func && fargs.length != 0) {
				pnl.inlineError("you are calling function '" ~ func ~ "' with the following arguments which are not present:");
				for(uint i = 0; i < fargs.length; i++) {
					pnl.inlineError("+---> '" ~ fargs[i] ~ '\'');
				}
			}
			
			if(func_href.length || behaviour.length) {
				rpc_link ~= ",'";
				
				ivar = 0;
				istr = 0;
				
				for(uint i; i < func_var_type.length; i++) {
					uint v_type = func_var_type[i];
					var_type ~= v_type;
					if(v_type == pnl_action_var_str) {
						variable_str ~= func_variable_str[istr++];
					} else {
						variable ~= func_variable[ivar++];
					}
					
					var_loc ~= func_var_loc[i] + rpc_link.length;
				}
				
				rpc_link ~= func_href ~ '\'';
				if(behaviour.length) {
					rpc_link ~= ",'" ~ behaviour ~ '\'';
				}
			}
			
			if(func_arg_count++) {
				func_href ~= '&';
			}
			
			func_href ~= "f=" ~ func;
		}
		
		if(!in_js) {
			val = "class" in link_opts;
			if(val) {
				custom_class = *val;
			}
			
			val = "id" in link_opts;
			if(val) {
				custom_id = *val;
			}
			
			val = "style" in link_opts;
			if(val) {
				custom_style = *val;
			}
			
			bool multipart = ("multipart" in link_opts ? true : false);
			
			if(func.length && func[0] == '$') {
				pnl.inlineError("Link construct cannot yet parse variables as input to 'function:'");
			}
			
			if(custom_class.length && custom_class[0] == '$') {
				pnl.inlineError("Link construct cannot yet parse variables as input to 'class:'");
			}
			
			bool no_z = false;
			if(arg_count == 0 && func_arg_count == 0 && panel_list.length == 0) {
				no_z = true;
				rpc_link.length = rpc_link.length - 4; // 4 bytes -> z(''
				panel_list = "javascript::void(0)";
			} else {
				panel_list = "?z=" ~ panel_list;
			}
			
			
			if(!no_z) {
				rpc_link ~= ')';
			}
			
			rpc_link ~= `" href="` ~ panel_list;
			if(arg_count) {
				rpc_link ~= '&';
			}
			
			ivar = 0;
			istr = 0;
			for(uint i = 0; i < href_var_type.length; i++) {
				uint v_type = href_var_type[i];
				var_type ~= v_type;
				if(v_type == pnl_action_var_str) {
					variable_str ~= href_variable_str[istr++];
				} else {
					variable ~= href_variable[ivar++];
				}
				
				var_loc ~= href_var_loc[i] + rpc_link.length + (no_z ? -4 : 0);
			}
			
			rpc_link ~= href;
			if(func_arg_count) {
				rpc_link ~= '&';
			}
			
			
			ivar = 0;
			istr = 0;
			for(uint i = 0; i < func_var_type.length; i++) {
				uint v_type = func_var_type[i];
				var_type ~= v_type;
				if(v_type == pnl_action_var_str) {
					variable_str ~= func_variable_str[istr++];
				} else {
					variable ~= func_variable[ivar++];
				}
				
				var_loc ~= func_var_loc[i] + rpc_link.length + (no_z ? -4 : 0);
			}
			
			rpc_link ~= func_href ~ '"';
			
			if(custom_class.length) {
				rpc_link ~= ` class="` ~ custom_class ~ '"';
			}
			
			if(custom_id.length) {
				rpc_link ~= ` id="` ~ custom_id ~ '"';
			}
			
			if(custom_style.length) {
				rpc_link ~= ` style="` ~ custom_style ~ '"';
			}
			
			
			if(is_button) {
				rpc_link ~= ` value="`;
				if("value" in link_opts) {
					rpc_link ~= link_opts["value"] ~ '"';
				} else {
					rpc_link ~= '"';
					errorln("You really should put a value for your button");
				}
			}
			
			rpc_link ~= '>';
		} else {
			rpc_link ~= ");";
		}
		
		this.link = rpc_link;
	}
	
	private string link;
	private string[] preserve;
	
	private uint[] var_type;
	private char*[] variable;
	private string*[] variable_str;
	private uint[] var_loc;
	
	void render() {
		uint last_var = 0;
		
		ulong ivar = 0;
		ulong istr = 0;
		
		for(uint i = 0; i < var_type.length; i++) {
			uint next_var = var_loc[i];
			prt(link[last_var .. next_var]);
			last_var = next_var;
			
			
			switch(var_type[i]) {
				default:
				case pnl_action_var_uint:
					//OPTIMIZE!!! create a uint prt function
					prt(Integer.toString(*cast(uint*)variable[ivar++]));
				break;
				case pnl_action_var_int:
					//OPTIMIZE!!! create a int prt function
					prt(Integer.toString(*cast(int*)variable[ivar++]));
				break;
				case pnl_action_var_str:
					//OPTIMIZE!!! create a url encoded prt function
					prt(uri_encode(*variable_str[istr++]));
				break;
			}
		}
		
		prt(link[last_var .. $]);
	}
}

version(unittests) {
	class TestTemplateLink : Unittest {
		static this() { Unittest.add(typeof(this).stringof, new typeof(this));}
		
		void prepare() {
			reset_state();
		}
		
		void clean() {
			reset_state();
		}
		
		void test() {
			clean();
			test1();
			
			clean();
			test2();
			
			clean();
			test3();
			
			clean();
			test4();
			
			clean();
			test5();
			
			clean();
			test6();
			
			clean();
			test7();
			
			clean();
			test8();
			
			clean();
			test9();
			
			clean();
			test10();
		}
		
		void test1() {
			PNL.parse_text(`
				<?interface panel:'link1' ?>
				<?link panels: "j:profile" ?>
			`);
			
			assert("link1" in PNL.pnl);
			version(testbytecode) PNL.pnl["link1"].print_bytecode;
			PNL.pnl["link1"].render();
			assert(out_tmp[0 .. out_ptr] == `<a onclick="return z('j:profile')" href="?z=j:profile">`);
		}
		
		void test2() {
			PNL.parse_text(`
				<?interface panel:'link2' ?>
				<?link panels: "j:profile" class: "custom" ?>
			`);
			
			assert("link2" in PNL.pnl);
			version(testbytecode) PNL.pnl["link2"].print_bytecode;
			PNL.pnl["link2"].render();
			assert(out_tmp[0 .. out_ptr] == `<a onclick="return z('j:profile')" href="?z=j:profile" class="custom">`);
		}
		
		void test3() {
			PNL.parse_text(`
				<?interface panel:'link3' ?>
				<?link panels: { j: "profile" } class: "custom" ?>
			`);
			
			assert("link3" in PNL.pnl);
			PNL.pnl["link3"].render();
			assert(out_tmp[0 .. out_ptr] == `<a onclick="return z('j:profile')" href="?z=j:profile" class="custom">`);
		}
		
		void test4() {
			PNL.parse_text(`
				<?interface panel:'link4' ?>
				<?link panels: { j: "profile", k: "invite" } class: "custom" ?>
			`);
			
			assert("link4" in PNL.pnl);
			PNL.pnl["link4"].render();
			
			assert(out_tmp[0 .. out_ptr] == `<a onclick="return z('k:invite,j:profile')" href="?z=k:invite,j:profile" class="custom">` ||
				out_tmp[0 .. out_ptr] == `<a onclick="return z('j:profile,k:invite')" href="?z=j:profile,k:invite" class="custom">`);
		}
		
		void test5() {
			PNL.parse_text(`
				<?interface panel:'link5' ?>
				<?link panels: { j: "profile", k: "invite" } args: { uid: 11 } class: "custom" ?>
			`);
			
			assert("link5" in PNL.pnl);
			PNL.pnl["link5"].render();
			
			assert(out_tmp[0 .. out_ptr] == `<a onclick="return z('k:invite,j:profile','uid=11')" href="?z=k:invite,j:profile&uid=11" class="custom">` ||
				out_tmp[0 .. out_ptr] == `<a onclick="return z('j:profile,k:invite','uid=11')" href="?z=j:profile,k:invite&uid=11" class="custom">`);
		}
		
		void test6() {
			PNL.parse_text(`
				<?interface panel:'link6' ?>
				<?load TestObject ?>
				<?link panels: { j: "profile", k: "invite" } args: { uid: $number } class: "custom" ?>
			`);
			
			assert("link6" in PNL.pnl);
			PNL.pnl["link6"].render();
			
			assert(out_tmp[0 .. out_ptr] == `<a onclick="return z('k:invite,j:profile','uid=7')" href="?z=k:invite,j:profile&uid=7" class="custom">` ||
				out_tmp[0 .. out_ptr] == `<a onclick="return z('j:profile,k:invite','uid=7')" href="?z=j:profile,k:invite&uid=7" class="custom">`);
		}
		
		void test7() {
			PNL.parse_text(`
				<?interface panel:'link7' ?>
				<?load TestObject ?>
				<?link panels: { j: "profile", k: "invite" } args: { uid: $number, lala: "word up homie" } class: "custom" ?>
			`);
			
			assert("link7" in PNL.pnl);
			PNL.pnl["link7"].render();
			
			assert(out_tmp[0 .. out_ptr] == `<a onclick="return z('k:invite,j:profile','lala=word%20up%20homie&uid=7')" href="?z=k:invite,j:profile&lala=word%20up%20homie&uid=7" class="custom">` ||
				out_tmp[0 .. out_ptr] == `<a onclick="return z('j:profile,k:invite','uid=7&lala=word%20up%20homie')" href="?z=j:profile,k:invite&uid=7&lala=word%20up%20homie" class="custom">`);
		}
		
		void test8() {
			PNL.parse_text(`
				<?interface panel:'link8' ?>
				<?load TestObject ?>
				<?=string?>
				<?link panels: { j: "profile", k: "invite" } args: { uid: $number, lala: $string } class: "custom" ?>
			`);
			
			assert("link8" in PNL.pnl);
			PNL.pnl["link8"].render();
			
			assert(out_tmp[0 .. out_ptr] == `test text<a onclick="return z('k:invite,j:profile','lala=test%20text&uid=7')" href="?z=k:invite,j:profile&lala=test%20text&uid=7" class="custom">` ||
				out_tmp[0 .. out_ptr] == `test text<a onclick="return z('j:profile,k:invite','uid=7&lala=test%20text')" href="?z=j:profile,k:invite&uid=7&lala=test%20text" class="custom">`);
		}
		
		void test9() {
			PNL.parse_text(`
				<?interface panel:'link9' ?>
				<?load TestObject ?>
				<?=string?>
				<?link panels: { j: "profile", k: "invite" } args: { uid: $number, lala: $string } class: "custom" button: true value:"MOOO!" ?>
			`);
			
			assert("link9" in PNL.pnl);
			PNL.pnl["link9"].render();
			
			assert(out_tmp[0 .. out_ptr] == `test text<input type="button" onclick="return z('k:invite,j:profile','lala=test%20text&uid=7')" href="?z=k:invite,j:profile&lala=test%20text&uid=7" class="custom" value="MOOO!">` ||
				out_tmp[0 .. out_ptr] == `test text<input type="button" onclick="return z('j:profile,k:invite','uid=7&lala=test%20text')" href="?z=j:profile,k:invite&uid=7&lala=test%20text" class="custom" value="MOOO!">`);
		}
		
		void test10() {
			PNL.parse_text(`
				<?interface panel:'link10' ?>
				<?load Url {lala: uint } ?>
				<?load TestObject {number3: $Url.lala } ?>
				<?=Url.lala?>-<?=number3?>
				<?link panels: { j: "profile", k: "invite" } args: { uid: $Url.lala, lala: $string } class: "custom" button: true value:"MOOO!" ?>
			`);
			
			POST["lala"] = "11";
			assert("link10" in PNL.pnl);
			PNL.pnl["link10"].render();
			
			assert(out_tmp[0 .. out_ptr] == `11-11<input type="button" onclick="return z('k:invite,j:profile','lala=test%20text&uid=11')" href="?z=k:invite,j:profile&lala=test%20text&uid=11" class="custom" value="MOOO!">` ||
				out_tmp[0 .. out_ptr] == `11-11<input type="button" onclick="return z('j:profile,k:invite','uid=11&lala=test%20text')" href="?z=j:profile,k:invite&uid=11&lala=test%20text" class="custom" value="MOOO!">`);
		}
	}
}

class TemplateForm : TemplateLink {
	
	static private typeof(this)[] instances;
	
	static this() {
		PNL.registerTemplate("form", &this.create);
		PNL.registerTemplate("endform", &this.create);
	}
	
	static private void create(inout PNL pnl, string cmd, string inside) {
		if(cmd == "form") {
			instances ~= new typeof(this)(pnl, inside);
			PNLByte* p = pnl.newByte();
			p.action = pnl_action_template;
			p.dg = &instances[$ - 1].render;
		} else if(cmd == "endform") {
			PNLByte* p = pnl.newByte();
			p.action = pnl_action_var_literal_str;
			p.ptr_str = pnl.getConst("</form>");
			in_func = false;
		}
	}
	
	this(inout PNL pnl, string params) {
		super(pnl, params, true);
		
		string* val;
		string[string] link_opts;
		string custom_class;
		
		link_opts.parse_options(params);
		
		val = "class" in link_opts;
		if(val) {
			custom_class = *val;
		}
		
		size_t href_loc = find(link, `href="`)+6;
		size_t end_href_loc = find(link, '"', href_loc); 
		string action = link[href_loc .. end_href_loc];
		
		auto this_variable = variable.dup;
		auto this_variable_str = variable_str.dup;
		auto this_var_type = var_type.dup;
		auto this_var_loc = var_loc.dup;
		
		variable = null;
		variable_str = null;
		var_type = null;
		var_loc = null;
		
		bool multipart = (find(params, "multipart") != -1 ? true : false);
		link = `<form method="post"` ~ (multipart ? ` enctype="multipart/form-data"` : null) ~  ` action="`;
		
		
		ulong istr = 0;
		ulong ivar = 0;
		
		for(uint i = 0; i < this_var_type.length; i++) {
			int loc = this_var_loc[i];
			if(loc >= href_loc && loc <= end_href_loc) {
				var_loc ~= this_var_loc[i] - href_loc + link.length;
				uint v_type = this_var_type[i];
				var_type ~= v_type;
				if(v_type == pnl_action_var_str) {
					variable_str ~= this_variable_str[istr++];
				} else {
					variable ~= this_variable[ivar++];
				}
			}
		}
		
		val = "validate_expression" in link_opts;
		if(val) {
			link ~= action ~ `" onsubmit="if(` ~ *val ~ `)new IF(this);return false"`;
		} else {
			link ~= action ~ `" onsubmit="new IF(this);return false"`;
		}
		
		val = "id" in link_opts;
		if(val) {
			link ~= ` id="` ~ *val ~ '"';
		}
		
		val = "class" in link_opts;
		if(val) {
			link ~= ` class="` ~ *val ~ `">`;
		} else {
			link ~= '>';
		}
	}
}

version(unittests) {
	class TestTemplateForms : Unittest {
		static this() { Unittest.add(typeof(this).stringof, new typeof(this));}
		
		void prepare() {
			reset_state();
		}
		
		void clean() {
			reset_state();
		}
		
		void test() {
			clean();
			test1();
			
			clean();
			test2();
			
			clean();
			test3();
			
			clean();
			test4();
		}
		
		void test1() {
			PNL.exportFunction("test_function", cast(int function())0);
			PNL.parse_text(`
				<?interface panel:'form1' ?>
				<?load TestObject ?>
				<?form panels: { j: "profile", k: "invite" } func: "test_function" class: "custom" ?>
					<input type='text' name='username' />
					<input type='text' name='password' />
					<input type='submit' value='Submit Button' />
				<?endform?>
			`);
			
			assert("form1" in PNL.pnl);
			version(testbytecode) PNL.pnl["form1"].print_bytecode;
			PNL.pnl["form1"].render();
			
			assert(out_tmp[0 .. out_ptr] == `<form method="post" action="?z=k:invite,j:profile&f=test_function" onsubmit="new IF(this);return false" class="custom"><input type='text' name='username' /><input type='text' name='password' /><input type='submit' value='Submit Button' /></form>` ||
				out_tmp[0 .. out_ptr] == `<form method="post" action="?z=j:profile,k:invite&f=test_function" onsubmit="new IF(this);return false" class="custom"><input type='text' name='username' /><input type='text' name='password' /><input type='submit' value='Submit Button' /></form>`);
			
			PNL.funcs.remove("test_function");
		}
		
		void test2() {
			PNL.exportFunction("test_function", cast(int function())0);
			PNL.parse_text(`
				<?interface panel:'form2' ?>
				<?load TestObject ?>
				<?form panels: { j: "profile", k: "invite" } func: "test_function" multipart: true class: "custom" ?>
					<input type='text' name='username' />
					<input type='text' name='password' />
					<input type='submit' value='Submit Button' />
				<?endform?>
			`);
			
			assert("form2" in PNL.pnl);
			version(testbytecode) PNL.pnl["form2"].print_bytecode;
			PNL.pnl["form2"].render();
			
			assert(out_tmp[0 .. out_ptr] == `<form method="post" enctype="multipart/form-data" action="?z=k:invite,j:profile&f=test_function" onsubmit="new IF(this);return false" class="custom"><input type='text' name='username' /><input type='text' name='password' /><input type='submit' value='Submit Button' /></form>` ||
				out_tmp[0 .. out_ptr] == `<form method="post" enctype="multipart/form-data" action="?z=j:profile,k:invite&f=test_function" onsubmit="new IF(this);return false" class="custom"><input type='text' name='username' /><input type='text' name='password' /><input type='submit' value='Submit Button' /></form>`);
			
			PNL.funcs.remove("test_function");
		}
		
		void test3() {
			PNL.exportFunction("test_function", cast(int function())0);
			POST["h"] = "lalalalala";
			PNL.parse_text(`
				<?interface panel:'form3' ?>
				<?load TestObject ?>
				<%load Url { h: string } %>
				<%form panels: { j: profile } func: "test_function" func_args: {hash: $Url.h}%>
					<input type='text' name='username' />
					<input type='text' name='password' />
					<input type='submit' value='Submit Button' />
				<?endform?>
			`);
			
			assert("form3" in PNL.pnl);
			version(testbytecode) PNL.pnl["form3"].print_bytecode;
			PNL.pnl["form3"].render();
			assert(out_tmp[0 .. out_ptr] == `<form method="post" action="?z=j:profile&f_hash=lalalalala&f=test_function" onsubmit="new IF(this);return false"><input type='text' name='username' /><input type='text' name='password' /><input type='submit' value='Submit Button' /></form>`);
			
			PNL.funcs.remove("test_function");
		}
		
		void test4() {
			PNL.parse_text(`
				<?interface panel:'form4' ?>
				<?load TestObject ?>
				<?form function: "func" preserve: "uid" panels: {m: "p"} ?>
					<input type='text' name='username' />
					<input type='text' name='password' />
					<input type='submit' value='Submit Button' />
				<?endform?>
			`);
			
			assert("form4" in PNL.pnl);
			PNL.pnl["form4"].render();
			
			assert(out_tmp[0 .. out_ptr] == `<form method="post" action="?z=m:p" onsubmit="new IF(this);return false"><input type='text' name='username' /><input type='text' name='password' /><input type='submit' value='Submit Button' /></form>`);
		}
	}
}

