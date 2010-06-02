module panel;

import libowfat;

import core;
import lib;
import shared;
import objects;
version(unittests) import unittests;

//extern(C) void delegate() new_object(int scope_level, string name, inout PNL pnl, string[string] params);

struct Resource {
	string name;
	string dir;
	string ver;
	string type;
}

struct Interface {
	string name;
	bool is_public;
	bool is_authenticator;
	bool is_func_return;
	char mode;
	char type;
}

interface TemplateInterface {
	static void create(inout PNL pnl, string cmd, string inside);
}

interface TemplateObject {
	void register(inout PNL pnl, inout string[string] params);
	void load();
}

// in order to account for expressions, (which may or may not be done any time soon (unless I have a really good reason for having them)
// if the variable pointer is 0, then it'll look into the universal "local" variable.
// there are various things that can be done to it, such as the following:
// var2 > (var1 + 3) -> action_load_uint -> action_add 3 -> action_jle (var2)

enum {
	pnl_action_text = 1,
	pnl_action_reserved = 2,
	pnl_action_je = 3,
	pnl_action_jne = 4,
	pnl_action_jg = 5,
	pnl_action_jl = 6,
	pnl_action_jge = 7,
	pnl_action_jle = 8,
	pnl_action_jmp = 9,
}


//FOR NOW, this will be an "byte code" language, but, eventually, I will implement JIT, or allow for modules to be precompiled and loaded as .so files
// After looking into it, it'd be so awesome to implement llvm as the JIT compiler

enum {
	pnl_action_var_uint = 11,
	pnl_action_var_int = 12,
	pnl_action_var_str = 13,
	pnl_action_var_float = 14,
	pnl_action_var_ulong = 15,
	pnl_action_var_long = 16,
	pnl_action_var_literal_str = 23,
	
	pnl_action_set_uint = 17,
	pnl_action_set_int = 18,
	pnl_action_set_str = 19,
	pnl_action_set_ulong = 20,
	pnl_action_set_long = 21,
	pnl_action_set_var_uint = 22,
	pnl_action_set_var_ulong = 24,
	pnl_action_set_var_str = 25,
	
	pnl_action_jenny = 26,
	pnl_action_loop = 33,
	pnl_action_void_function = 37,
	pnl_action_void_delegate = 39,
	
	pnl_action_template = 69,
	pnl_action_panel = 70,
	pnl_action_final_replace = 71,
	
	pnl_action_uint_mask = 0x000000,
	pnl_action_int_mask = 0x100000,
	pnl_action_var_str_mask = 0x200000,
	pnl_action_var_int_mask = 0x400000,
	pnl_action_func_mask = 0x800000,
}

enum {
	PNL_TYPE_PANEL = 1,
	PNL_TYPE_PUBLIC = 2,
	PNL_TYPE_FUNC = 3,
	PNL_TYPE_RESOURCE = 4,
}


// Starbucks: where most modern apostasy is conceived
// Starbucks: where feelings are more effective than the gospel
// Starbucks: redefining superficial
// Starbucks: Industrious conversation and productive words
// Starbucks: Modern Comfort
// Starbucks: Coffeensation (coffee, caffeine, sensation and conversation)

class PNLByte {
	align(4) {
		uint action;
		union {
			//for text, end of text
			uint ptr_end;
			// for comparisons, jump to this location
			uint new_location;
			// for text truncation
			int truncate;
		}
	}
	
	union {
		char* ptr;
		string* ptr_str;
	}
	
	union {
		//for text, beginning of text
		uint ptr_start;
		
		// for comparison's the value to compare with (unused if var-2-var comparison)
		uint value;
		int int_value;
		long long_value;
		ulong ulong_value;
		string str_value;
	}
	
	union {
		
		//ptr to the second var (in var-2-var) comparison
		char* ptr2;
		string* ptr_str2;
		
		void function() fp;
		void function(string) callback;
		void delegate() dg;
		int delegate(string) int_dg;
		long delegate(string) long_dg;
	}
}

class TemplateFrame {
	string name;
	string custom_class;
	bool hidden;
	
	PNL* default_panel;
	string default_panel_str;
	
	
	this(string name, string custom_class = "", bool hidden = false) {
		this.name = name;
		this.custom_class = custom_class;
		this.hidden = hidden;
	}
	
	void render() {
		prt(`<div id="`);
		prt(name);
		if(custom_class.length > 0) {
			prt(`" class="`);
			prt(custom_class);
		}
		
		if(hidden != false) {
			prt(`" style="display:none`);
		}
		
		prt(`">`);
		
		string* ptr_frame = (name in PANELS);
		PNL* ptr_panel;
		
		ptr_panel = ptr_frame ? *ptr_frame in PNL.pnl : default_panel; 
		if(!ptr_panel) {
			default_panel = ptr_panel = default_panel_str in PNL.pnl;
		}
		
		if(ptr_panel) {
			if(uid || ptr_panel.is_public) {
				ptr_panel.render();
			} else {
				if(PNL.pnl_auth) {
					PNL.pnl_auth.render();
				} else {
					prt("You need to add an authenticator panel");
				}
			}
		} else {
			debug {
				errorln("You are requesting to load panel '", *ptr_frame, "' into frame '", name, "' but that's not a valid option");
				errorln("available:");
				foreach(name, p; PNL.pnl) {
					errorln("   '", name, "'");
				}
			}
		}
		
		prt("</div>");
	}
}

struct final_replace {
	uint offset;
	string* ptr;
}


final class PNL {
	import Memory = tango.core.Memory;
	import FileScan = tango.io.FileScan;
	import tango.io.device.File : File;
	import tango.io.FilePath : FilePath;
	import Integer = tango.text.convert.Integer;
	import Float = tango.text.convert.Float;
	import tango.core.Memory : GC;
	
	private static PNL[string] pnl;
	private static PNL[string] func_ret_pnl;
	private static string s_pnl_auth;
	private static PNL* pnl_auth;
	version(unittests) {
		private static bool[string] public_pnl;
	} else {
		version(notrelease) private static bool[string] public_pnl;
	}
	
	static string[128] str_const_vars;
	static string[128] str_local_vars;
	static string[16] str_global_vars;
	
	private static PNLByte[] PB;
	private static TemplateFrame[] PANELS;
	private static TemplateFrame*[] panels;
	private static string[string][string] lang;
	private static string[] idiomas;
	private static string default_idioma = "en";
	private static void function(inout PNL pnl, string cmd, string inside)[string] templates;
	private static int function()[string] public_funcs;
	private static int function()[string] funcs;
	private static string[][string] func_args;
	private static uint[string] global_var_type;
	private static char*[string] global_var_ptr;
	private static string*[string] global_var_str;
	
	private static final_replace[] final_replacements;
	private static bool preserve_newlines;
	private static bool preparse;
	private static string[string] inline_panels;
	
	private static reload_resources = false;
	
	version(unittests) {
		static void reset_state() {
			pnl = null;
			func_ret_pnl = null;
			
			PB.length = 0;
			PANELS.length = 0;
			panels.length = 0;
			
			foreach(l; public_funcs.keys) {
				public_funcs.remove(l);
			}
			
			foreach(l; funcs.keys) {
				funcs.remove(l);
			}
			
			foreach(l; func_args.keys) {
				func_args.remove(l);
			}
			
			foreach(l; inline_panels.keys) {
				inline_panels.remove(l);
			}
			
			public_funcs = null;
			funcs = null;
			func_args = null;
			inline_panels = null;
			
			foreach(l; public_pnl.keys) {
				inline_panels.remove(l);
			}
			
			public_pnl = null;
		}
	}
	
	static bool load_idioma(FilePath fp) {
		string name = fp.toString();
		stdoutln("loading idoma: ", name);
		parse_idioma(name);
		
		return true;
	}
	
	static bool load_panel(FilePath fp) {
		string filename = fp.toString();
		if(filename.length && filename[$-1] != '~') {
			stdoutln(preparse ? "preparsing" : "loading", " panel: ", filename);
			parse_file(filename, preparse);
		}
		
		return true;
	}
	
	static void reload_panels(string panels_dir, string lang_dir) {
		pnl = null;
		PB = null;
		static_objects = null;
		static_object_loaded = null;
		GC.collect();
		//title.length = 50;
		//title.length = 0;
		
		debug noticeln("-- Loading Panels --");
		
		// preparse all languages
		scan_dir(FilePath(lang_dir), &load_idioma, 100);
		
		// preparse all the functions
		preparse = true;
		scan_dir(FilePath(panels_dir), &load_panel, 100);
		
		// parse all panels
		preparse = false;
		scan_dir(FilePath(panels_dir), &load_panel, 100);
		
		foreach(inout PNL p; PNL.pnl) {
			foreach(TemplateFrame* tp; p.panels) {
				if(!tp.default_panel && tp.default_panel_str.length) {
					tp.default_panel = (tp.default_panel_str in PNL.pnl);
				}
			}
		}
		
		if(s_pnl_auth.length) {
			pnl_auth = s_pnl_auth in pnl;
		}
		
		version(notrelease) {
			if(public_pnl.length && public_pnl.length < pnl.length && !pnl_auth) {
				errorln("ERROR: you have public and private panels, but no authentication panel");
				errorln("public panels:");
				foreach(str_panel, p; public_pnl) {
					errorln(str_panel);
				}
				
				errorln("\nprivate panels:");
				foreach(str_panel, p; pnl) {
					if(!(str_panel in public_pnl)) {
						errorln(str_panel);
					}
				}
			}
			
			
		}
		
		s_pnl_auth = null;
		reload_resources = false;
		GC.collect();
		debug noticeln("-- Finished Loading Panels --");
	}
	
	private static void parse_idioma(string filename) {
		auto content = cast(string)File.get(filename);
		if(content.length && filename[$-4 .. $] == ".txt") {
			auto bar_pos = findr_c(filename, '/'); // cheap hack, because findr will return -1 if it's not found
			string file_lang = filename[++bar_pos .. $-4];
			
			content = replace_cc(content, '\n', ' ');
			string[string] text;
			text.parse_options(content);
			
			lang[file_lang] = text;
		} else {
			debug errorln("file '", filename, "' is empty");
		}
	}
	
	private static void parse_file(string filename, bool preparse) {
		auto text = cast(string)File.get(filename);
		if(text.length) {
			parse_text(text, preparse);
		} else {
			debug errorln("file '", filename, "' is empty");
		}
	}
	
	static void parse_text(string text, bool preparse = false) {
		auto len = text.length;
		if(len) {
			string* val;
			
			int type;
			Resource resource;
			Interface panel;
			bool preserve_newlines = settings.preserve_newlines;
			int[TEMPLATE_MAX_LINES] lines;
			int cur_line = 0;
			
			typeof(len) i = 0;
			typeof(len) cur = 0;
			
			// remove beginning spaces and newlines
			while(i < len && text[i] <= ' ') {
				i++;
			}
			
			char[] t = text[i .. $] ~ "        "; // the padding is for buffer overruns
			char[] new_text = " ";
			new_text.length = len;
			
			auto first_line = find_c(t, '\n');
			auto first_cr = find_c(t, '\r');
			noticeln("ln: ", first_line, " cr: ", first_cr);
			if(first_cr != -1 && first_cr < first_line) {
				t = t[0 .. first_cr] ~ "\n<error>please do not save in file formats other than linux file format (newlines \\n)</error>" ~ replace_cc(t[first_line .. $], '\r', '\n');
				debug errorln("NEWLINE ERROR '", t[0 .. 200]);
				first_line = find_c(t, '\n');
			}
			
			if(first_line != -1 && first_line > 20) { //<%interface ...%> is the minimum
				if(t[0] == '<' && (t[1] == '?' || t[1] == '%') && t[first_line-1] == '>' && (t[first_line-2] == '?' || t[first_line-2] == '%')) {
					typeof(len) end_cmd = 1;
					while(end_cmd < first_line && t[end_cmd] > ' ') {
						end_cmd++;
					}
					
					string cmd = t[2 .. end_cmd];
					string inside = trim(t[end_cmd+1 .. first_line-2]);
					
					if(cmd == "interface") {
						if(inside.length) {
							type = PNL_TYPE_PANEL;
							
							string[string] options;
							options.parse_options(inside);
							
							val = "preserve_newlines" in options;
							if(val) {
								preserve_newlines = cast(bool)toUint(*val);
							}
							
							val = "panel" in options;
							if(val) {
								if(preparse) {
									// if we're preparsing we definitely don't want to look at panels
									return;
								} else {
									panel.name = *val;
								}
							} else {
								val = "name" in options;
								if(val) {
									noticeln("'<%interface name: ...' is depricated. please use '<%interface panel: ...'");
									if(preparse) {
										return;
									} else {
										panel.name = *val;
									}
								} else {
									val = "func_return" in options;
									if(val) {
										if(preparse) {
											return;
										} else {
											panel.is_func_return = true;//cast(bool)toUint(*val);
											panel.name = *val;
										}
									} else {
										val = "func" in options;
										if(val) {
											if(preparse) {
												// we only want to parse functions if we're preparsing
												panel.name = *val;
												type = PNL_TYPE_FUNC;
											} else {
												return;
											}
										} else {
											debug errorln("interface must have a name");
										}
									}
								}
							}
							
							
							
							val = "public" in options;
							if(val) {
								panel.is_public = true;
							}
							
							val = "mode" in options;
							if(val) {
								switch(*val) {
								case "append_noreplace":
									panel.mode = MODE_APPEND_NO_REPLACE;
									break;
								case "append":
									panel.mode = MODE_APPEND;
									break;
								case "js":
									panel.mode = MODE_JS;
									break;
								default:
								case "replace":
									panel.mode = MODE_REPLACE;
								}
							} else {
								panel.mode = MODE_REPLACE;
							}
							
							val = "authenticator" in options;
							if(val) {
								debug {
									if(PNL.s_pnl_auth.length) {
										noticeln("overwriting previous authentication panel (" ~ PNL.s_pnl_auth ~ ") with '" ~ panel.name ~ ")");
									}
								}
								
								panel.is_authenticator = true;
							}
							
							version(testbytecode) {
								val = "bytecode" in options;
								if(val) {
									PNL.finished_print_bytecode = true;
								}
							}
						} else {
							debug errorln("LOL: you have an interface without any options");
						}
					} else if(cmd == "resource") {
						if(preparse) {
							return;
						}
						
						// do resource stuff...
						if(inside.length) {
							type = PNL_TYPE_RESOURCE; // magick number!!!
							
							debug preserve_newlines = true;
							string[string] options;
							options.parse_options(inside);
							
							val = "preserve_newlines" in options;
							if(val) {
								preserve_newlines = cast(bool)toUint(*val);
							}
							
							val = "type" in options;
							if(val) {
								resource.type = *val;
								switch(resource.type) {
								case "js":
									resource.type = "text/javascript";
								case "css":
									resource.type = "text/css";
								default:
								}
							} else {
								resource.type = "text/javascript";
							}
							
							val = "version" in options;
							if(val) {
								resource.ver = *val;
							}
							
							val = "name" in options;
							if(val) {
								resource.name = *val;
								panel.name = "!rc!" ~ *val;
							}
							
							val = "dir" in options;
							if(val) {
								resource.dir = *val;
							}
							
							version(testbytecode) {
								val = "bytecode" in options;
								if(val) {
									PNL.finished_print_bytecode = true;
								}
							}
						} else {
							debug errorln("LOL: you have a resource without any options");
						}
					}
			
			
					i = ++first_line;
					// remove beginning spaces and newlines
					while(i < len && t[i] <= ' ') {
						if(t[i] == '\n') {
							if(preserve_newlines) {
								new_text[++cur] = '\n';
								new_text[cur] = ' ';
							}
							
							if(cur_line < TEMPLATE_MAX_LINES) {
								lines[cur_line++] = i;
							} else {
								debug errorln("template maximum number of lines exceeded");
							}
						}
						
						i++;
					}
					
					assert(new_text[cur] == ' ');
					char in_quote = 0;
					for(; i < len; i++) {
						if(t[i] < ' ') {
							if(t[i] == '\n') {
								if(preserve_newlines) {
									new_text[++cur] = '\n';
								}
								
								if(cur_line < TEMPLATE_MAX_LINES) {
									lines[cur_line++] = i;
								} else {
									debug errorln("template maximum number of lines exceeded");
								}
								
								i++;
								while(i < len && t[i] == ' ') {
									i++;
								}
								
								i--;
							} else {
								t[i] = ' ';
								if(t[i-1] != '\n' && t[i-1] != ' ') {
									i--;
								}
							}
						} else {
							// strip comments /* */ and //
							if(in_quote == 0 && t[i] == '/') {
								if(t[i+1] == '*') {
									while(i < len && !(t[i] == '/' && t[i-1] == '*')) {
										if(preserve_newlines && t[i] == '\n') {
											new_text[++cur] = '\n';
										}
										
										i++;
									}
									
									continue;
								} else if(t[i+1] == '/') {
									while(i < len && t[i] != '\n') {
										i++;
									}
									
									if(preserve_newlines) {
										new_text[++cur] = '\n';
									}
									
									continue;
								}
							}
							
							// get inside and outside of a quote
							if((t[i] == '"' || t[i] == '`') && t[i-1] != '\\') {
								if(in_quote != 0) {
									while(i < len && !(t[i] == in_quote && t[i-1] != '\\')) {
										if(t[i] == '\n') {
											if(preserve_newlines) {
												new_text[++cur] = '\n';
											}
											
											if(cur_line < TEMPLATE_MAX_LINES) {
												lines[cur_line++] = i;
											} else {
												debug errorln("template maximum number of lines exceeded");
											}
										}
										
										new_text[++cur] = t[i++];
									}
									
									in_quote = 0;
								} else {
									in_quote = t[i];
								}
							}
							
							// transform php tags into asp tags for the sake of awesomeness
							if(t[i] == '?' && (t[i-1] == '<' || t[i+1] == '>')) {
								t[i] = '%';
							}
							
							if(t[i] == '<' && t[i+1] == '!' && t[i+2] == '-' && t[i+3] == '-') {
								i += 3;
								while(i < len && !(t[i] == '>' && t[i-1] == '-' && t[i-2] == '-')) {
									i++;
								}
								
								i++;
							}
							
							if(!(t[i] == ' ' && new_text[cur] == ' ')) {
								if(t[i] == '<' && t[i+2] == '>') {
									if(t[i+1] == ' ') {
										new_text[++cur] = ' ';
										i += 2;
										continue;
									} else if(t[i+1] == 'n') {
										new_text[++cur] = '\n';
										i += 2;
										continue;
									}
								}
								
								/*if(str_start(&t[i], ` style="`)) {
									new_text[++cur .. cur+8] = ` style="`;
									i += 8;
									cur += 8;
									
									assert(t[i] != '"');
									assert(t[i-1] == '"');
									auto j = i;
									while(j < len && t[j] != '"') {
										j++;
									}
									
									string style = css_optimizer(t[i .. j]);
									new_text[++cur .. cur+style.length] = style;
									
								}*/
								
								new_text[++cur] = t[i];
							}
						}
					}
					
					if(new_text[cur] != ' ') {
						cur++;
					}
					
					new_text.length = cur;
					
					auto inline_start = find_noquote(new_text, "<%call");
					while(inline_start != -1) {
						auto inline_end = find_s(new_text, "%>", inline_start);
						if(inline_end != -1) {
							inside = new_text[inline_start+6 .. inline_end];
							if(inside.length) {
								string[string] options;
								options.parse_options(inside);
								
								val = "func" in options;
								if(val) {
									string func = *val;
									val = func in inline_panels;
									if(val) {
										string panel_txt = (*val).dup;
										val = "args" in options;
										if(val) {
											string[string] args;
											args.parse_options(*val);
											foreach(this_val, real_val; options) {
												panel_txt = replace_ss(panel_txt, "$this." ~ this_val, real_val);
												panel_txt = replace_ss(panel_txt, "this." ~ this_val, real_val);
											}
										}
										
										new_text = new_text[0 .. inline_start] ~ panel_txt ~ new_text[inline_end+2 .. $];
										inline_start = find_noquote(new_text, "<%call");
										continue;
									} else {
										errorln("the function you tried to call ('", func, "') does not exist");
									}
								} else {
									errorln("<%call must call a function!");
								}
							}
						}
						
						break;
					}
					
					inline_start = find_s(new_text, "{{=");
					while(inline_start != -1) {
						auto inline_end = find_noquote(new_text, "}}", inline_start);
						if(inline_end != -1) {
							auto inline_end_cmd = inline_end;
							for(auto j = inline_start; j < inline_end; j++) {
								if(new_text[j] == ' ') {
									inline_end_cmd = j;
									break;
								}
							}
							
							string lang_index = new_text[inline_start+3 .. inline_end_cmd];
							string* ptr_text = lang_index in lang["en"];
							
							new_text = new_text[0 .. inline_start] ~ (ptr_text ? *ptr_text : "!!untranslated text: '" ~ lang_index ~ '\'') ~ new_text[inline_end+2 .. $];
							inline_start = find_s(new_text, "{{=", inline_start);
						} else {
							inline_start = -1;
						}
					}
					
					
					if(cur_line > 0) {
						this.lines.length = --cur_line;
						this.lines[0 .. cur_line] = lines[0 .. cur_line];
					}
					
					if(new_text.length) {
						PNL p;
						if(!preparse) {
							p = new PNL(new_text[1 .. $], panel.name); // because it's padded with a space
						}
						
						version(testbytecode) {
							if(PNL.finished_print_bytecode) {
								p.print_bytecode();
								PNL.finished_print_bytecode = false;
							}
						}
						
						switch(type) {
							case PNL_TYPE_PANEL:
								p.name = panel.name;
								p.mode = panel.mode;
								p.is_public = panel.is_public;
								if(panel.is_func_return) {
									func_ret_pnl[panel.name] = p;
								} else {
									pnl[p.name] = p;
								}
								
								if(panel.is_authenticator) {
									PNL.s_pnl_auth = panel.name;
								}
								
								debug {
									if(panel.is_public) {
										PNL.public_pnl[panel.name] = true;
									}
								}
								
								break;
							
							case PNL_TYPE_RESOURCE:
								// if not found in filesystem
								string name = resource.name ~ '.' ~ resource.ver;
								string filename = settings.resources_dir ~ '/' ~ name;
								string data;
								if(!reload_resources && !settings.reload_resources && Path.exists(filename)) {
									data = cast(string)File.get(filename);
								} else {
									p.render();
									data = out_tmp[0 .. out_ptr];
									out_ptr = 0;
								
									File.set(filename, data);
								}
								
								serve_file(name, resource.dir, data, resource.type);
								delete p;
								break;
								
							case PNL_TYPE_FUNC:
								inline_panels[panel.name] = new_text[1 .. $];
								break;
							
							default:
								debug errorln("could not find name for panel");
						}
					}
				}
			}
		}
	}
	
	static void registerTemplate(string template_name, void function(inout PNL pnl, string, string) func) {
		templates[template_name] = func;
	}
	
	static void exportFunction(string func_name, int function() func) {
		funcs[func_name] = func;
	}
	
	static void exportPublicFunction(string func_name, int function() func) {
		public_funcs[func_name] = func;
	}
	
	static void exportFunctionArg(string func_name, string arg_name) {
		func_args[func_name] ~= arg_name;
	}
	
	//------------------------------
	
	enum {
		MODE_REPLACE = 1,
		MODE_APPEND,
		MODE_APPEND_NO_REPLACE,
		MODE_JS,
		MODE_CUSTOM
	}
	
	int mode;
	private PNLByte*[] pb;
	private uint pb_count = 0;
	private string text;
	string name;
	bool is_public;
	
	private int delegate()[int][string] obj_loops;
	private long function(string args)[int][string] obj_funcs;
	uint[string][uint] var_type;
	char*[string][uint] var_ptr;
	string*[string][uint] var_str;
	
	private int[string] obj_loop_inst;
	private int[string] obj_func_inst;
	private int[string] var_inst;
	
	private static int[] lines;
	
	private uint scopee = 0;
	private static bool first_text;
	
	this(string text, string name) {
		this.text = text.dup;
		this.name = name;
		//std.gc.hasNoPointers(cast(void*)this.text.ptr);
		pb.length = 0;
		first_text = true;
		scopee = 0;
		preserve_newlines = settings.preserve_newlines;
		
		registerString("sid", &.sid);
		registerInt("uid", &.uid);
		registerInt("zid", &.zid);
		registerInt("xid", &.xid);
		registerUint("zid.set", &.zid_set);
		registerUint("xid.set", &.xid_set);
		// TODO!!! - make this much more extensive in a template which parses the header
		registerInt("Browser.type", &.browser_type);
		registerInt("Browser.version", &.browser_version);
		registerUint("ip4", &.ip4);
		registerInt("func_ret", &.func_ret);
		registerString("func", &.func_name);
		registerString("div", &.div);
		registerString("query_string", &.query_string);
		registerString("title", &.title);
		registerString("js", &.Core.js_out);
		registerUint("is_me", &.is_me);
		
		parse_indent(0);
	}
	
	void registerFloat(string name, float* var, bool global = false) {
		if(global) {
			global_var_type[name] = pnl_action_var_float;
			global_var_ptr[name] = cast(char*) var;
		} else {
			int i = 0;
			int* inst = name in var_inst;
			
			if(inst) {
				i = ++(*inst);
			}
			
			var_type[i][name] = pnl_action_var_float;
			var_ptr[i][name] = cast(char*) var;
			var_inst[name] = i;
		}
	}
	
	void registerUint(string name, uint* var, bool global = false) {
		if(global) {
			global_var_type[name] = pnl_action_var_uint;
			global_var_ptr[name] = cast(char*) var;
		} else {
			int i = 0;
			int* inst = name in var_inst;
			
			if(inst) {
				i = ++(*inst);
			}
			
			var_type[i][name] = pnl_action_var_uint;
			var_ptr[i][name] = cast(char*)var;
			var_inst[name] = i;
		}
	}
	
	void registerInt(string name, int* var, bool global = false) {
		if(global) {
			global_var_type[name] = pnl_action_var_int;
			global_var_ptr[name] = cast(char*) var;
		} else {
			int i = 0;
			int* inst = name in var_inst;
			
			if(inst) {
				i = ++(*inst);
			}
			
			var_type[i][name] = pnl_action_var_int;
			var_ptr[i][name] = cast(char*)var;
			var_inst[name] = i;
		}
	}
	
	void registerLong(string name, long* var, bool global = false) {
		if(global) {
			global_var_type[name] = pnl_action_var_long;
			global_var_ptr[name] = cast(char*) var;
		} else {
			int i = 0;
			int* inst = name in var_inst;
			
			if(inst) {
				i = ++(*inst);
			}
			
			var_type[i][name] = pnl_action_var_long;
			var_ptr[i][name] = cast(char*)var;
			var_inst[name] = i;
		}
	}
	
	void registerUlong(string name, ulong* var, bool global = false) {
		if(global) {
			global_var_type[name] = pnl_action_var_ulong;
			global_var_ptr[name] = cast(char*) var;
		} else {
			int i = 0;
			int* inst = name in var_inst;
			
			if(inst) {
				i = ++(*inst);
			}
			
			var_type[i][name] = pnl_action_var_ulong;
			var_ptr[i][name] = cast(char*)var;
			var_inst[name] = i;
		}
	}
	
	void registerString(string name, string* var, bool global = false) {
		if(global) {
			if(name in global_var_type) {
				// probably unnecesary. don't do this...
				throw new Exception("variable '" ~ name ~ "' is already registered");
			}
			
			global_var_type[name] = pnl_action_var_str;
			global_var_str[name] = var;
		} else {
			if(var == null) {
				var = getLocalString();
			}
			
			int i = 0;
			int* inst = name in var_inst;
			
			if(inst) {
				i = ++(*inst);
			}
			
			var_type[i][name] = pnl_action_var_str;
			var_str[i][name] = var;
			var_inst[name] = i;
		}
	}
	
	void registerFunction(string name, long function(string args) func, bool global = false) {
		if(global) {
			errorln("global functions not yet available");
		} else {
			int i = 0;
			int* inst = name in obj_func_inst;
			
			if(inst) {
				i = ++(*inst);
			}
			
			obj_funcs[name][i] = func;
			obj_func_inst[name] = i;
		}
	}
	
	void registerLoop(string name, int delegate() incloop, bool global = false) {
		if(global) {
			errorln("global loops not yet available");
		} else {
			int i = 0;
			int* inst = name in obj_loop_inst;
			
			if(inst) {
				i = ++(*inst);
			}
			
			obj_loops[name][i] = incloop;
			obj_loop_inst[name] = i;
		}
	}
	
	alias registerObj registerIndex;
	static void registerObj(string name, TemplateObject function(inout PNL pnl, inout string[string] params) factory) {
		available_objects[name] = factory;
	}
	
	//SECURITY!!! - there are serious security risks with global variables. I should make sure and fix them asap
	uint* getGlobalUint(string name, bool global = false) {
		int i;
		if(!global && (i = find_var(name)) != -1) {
			uint* p_var_type = (name in var_type[i]);
			if(p_var_type && *p_var_type == pnl_action_var_uint) {
				return cast(uint*)*(name in var_ptr[i]);
			}
		} else {
			uint* p_var_type = name in global_var_type;
			if(p_var_type && *p_var_type == pnl_action_var_uint) {
				return cast(uint*)(name in global_var_ptr);
			}
		}
		
		if(global) {
			// kinda unintuitive, buf if we didn't find the global variable, we should make a local one
			uint* p_var = new uint;
			registerUint(name, p_var);
			return p_var;
		} else {
			return getGlobalUint(name, true);
		}
	}
	
	int* getGlobalInt(string name, bool global = false) {
		int i;
		if(!global && (i = find_var(name)) != -1) {
			uint* p_var_type = (name in var_type[i]);
			if(p_var_type && *p_var_type == pnl_action_var_int) {
				return cast(int*)*(name in var_ptr[i]);
			}
		} else {
			uint* p_var_type = name in global_var_type;
			if(p_var_type && *p_var_type == pnl_action_var_int) {
				return cast(int*)(name in global_var_ptr);
			}
		}
		
		if(global) {
			// kinda unintuitive, buf if we didn't find the global variable, we should make a local one
			int* p_var = new int;
			registerInt(name, p_var);
			return p_var;
		} else {
			return getGlobalInt(name, true);
		}
	}
	
	ulong* getGlobalUlong(string name, bool global = false) {
		int i;
		if(!global && (i = find_var(name)) != -1) {
			uint* p_var_type = (name in var_type[i]);
			if(p_var_type && *p_var_type == pnl_action_var_ulong) {
				return cast(ulong*)*(name in var_ptr[i]);
			}
		} else {
			uint* p_var_type = name in global_var_type;
			if(p_var_type && *p_var_type == pnl_action_var_ulong) {
				return cast(ulong*)(name in global_var_ptr);
			}
		}
		
		if(global) {
			// kinda unintuitive, buf if we didn't find the global variable, we should make a local one
			ulong* p_var = new ulong;
			registerUlong(name, p_var);
			return p_var;
		} else {
			return getGlobalUlong(name, true);
		}
	}
	
	long* getGlobalLong(string name, bool global = false) {
		int i;
		if(!global && (i = find_var(name)) != -1) {
			uint* p_var_type = (name in var_type[i]);
			if(p_var_type && *p_var_type == pnl_action_var_long) {
				return cast(long*)*(name in var_ptr[i]);
			}
		} else {
			uint* p_var_type = name in global_var_type;
			if(p_var_type && *p_var_type == pnl_action_var_long) {
				return cast(long*)(name in global_var_ptr);
			}
		}
		
		if(global) {
			// kinda unintuitive, buf if we didn't find the global variable, we should make a local one
			long* p_var = new long;
			registerLong(name, p_var);
			return p_var;
		} else {
			return getGlobalLong(name, true);
		}
	}
	
	string* getGlobalStr(string name, bool global = false) {
		int i;
		if(!global && (i = find_var(name)) != -1) {
			uint* p_var_type = (name in var_type[i]);
			if(p_var_type && *p_var_type == pnl_action_var_str) {
				return *(name in var_str[i]);
			}
		} else {
			uint* p_var_type = name in global_var_type;
			if(p_var_type && *p_var_type == pnl_action_var_str) {
				return *(name in global_var_str);
			}
		}
		
		if(global) {
			// kinda unintuitive, buf if we didn't find the global variable, we should make a local one
			string* p_var = getGlobalString("");
			registerString(name, p_var, true);
			return p_var;
		} else {
			return getGlobalStr(name, true);
		}
	}
	
	string* getConst(string string) {
		size_t const_index = -1;
		size_t null_index = -1;
		for(size_t k = 0; k < str_const_vars.length; k++) {
			if(str_const_vars[k] == string) {
				const_index = k;
				break;
			}
			
			if(null_index == -1 && str_const_vars[k] == null) {
				null_index = k;
			}
		}
		
		if(const_index == -1) {
			if(null_index != -1) {
				str_const_vars[null_index] = string.dup;
				const_index = null_index;
			} else {
				throw new Exception("no available space for more constants.. recompile with a bigger str_const_vars array");
			}
		}
		
		return &str_const_vars[const_index];
	}
	
	//TODO(!!) - on panel destruction, null out the strings it uses in the panels
	string* getLocalString(string val = "") {
		size_t index = -1;
		for(size_t k = 0; k < str_local_vars.length; k++) {
			if(str_local_vars[k] == null) {
				index = k;
				str_global_vars[k] = val.dup;
				break;
			}
		}
		
		if(index == -1) {
			throw new Exception("no available space for more strings.. recompile with a bigger str_local_vars array");
		}
		
		return &str_local_vars[index];
	}
	
	string* getGlobalString(string val = "") {
		size_t index = -1;
		for(size_t k = 0; k < str_global_vars.length; k++) {
			if(str_global_vars[k] == null) {
				index = k;
				str_global_vars[k] = val.dup;
				break;
			}
		}
		
		if(index == -1) {
			throw new Exception("no available space for more strings.. recompile with a bigger str_global_vars array");
		}
		
		return &str_global_vars[index];
	}
	
	int find_var(string name) {
		int* i = name in var_inst;
		if(i) {
			return *i;
		} else {
			return -1;
		}
	}
	
	int find_func(string name) {
		int* i = name in obj_func_inst;
		if(i) {
			return *i;
		} else {
			return -1;
		}
	}
	
	int find_loop(string name) {
		int* i = name in obj_loop_inst;
		if(i) {
			return *i;
		} else {
			return -1;
		}
	}
	
	void addDependency(string name) {
		//TODO!!! - FIX ME!
	}
	
	// I feel bad, because I keep laughing at these 3 fobs in front of me...
	// they're trying to learn english from this machine that tells them in the most mechanical voice, how to pronounce the word...
	//
	// fob1: dis-greet-eely -- huh huh huh huh
	// fob2: huh huh huh huh
	// fob1: pre-nuh-ptual -- huh hah huh huh huh
	// fob3: oooooooo -- huh huh huh
	// fob2: ahhhhhhh -- huh huh huh
	// fob1: wee're feeeniish
	// fob2: immmeeedetely --- oh oh
	// fob3: oh oh ahhh
	// fob1: dis-greet-reee
	//
	// fob1: ahh--peel-ing (waves hands in ta-da fashion)
	// fob2&3: ah?
	// fob1: aaaahhhhh--peeell-iing
	// fob2: (says something in japanese)
	// fob3: ahh-peer-ring
	// fob1: ohhhh -- huh huh huh -- ahh--peerr-ring
	
	PNLByte* newByte() {
		PB ~= new PNLByte;
		PNLByte* p = &PB[$ - 1];
		pb ~= p;
		pb_count++;
		return p;
	}
	
	void removeByte() {
		PB[$ - 1] = null;
		pb[$ - 1] = null;
		PB.length = PB.length-1;
		pb.length = pb.length-1;
		pb_count--;
	}
	
	void inlineError(string error) {
		//TODO!!! - add line numbers
		PNLByte* p = newByte();
		p.action = pnl_action_var_literal_str;
		p.ptr_str = getConst("<error>" ~ error ~ "</error>");
	}
	
	private uint parse_indent(uint start_char) {
		string* val;
		uint text_start = start_char;
		uint text_end = start_char;
		auto text_len = text.length;
		uint*[] jmp_list;
		int loop_return = -1;
		int[]  condition_jump;
		bool just_if = false;
		bool start_new_scope = true;
		
		// when start_new_scope is true, that means we're outside of an if-statement.
		// as soon as an if-statement is entered, then it will be set to false.
		// When endif is found, it's set to true.
		
		scopee++;
		
		uint i;
		for(i = start_char; i < text_len; i++) {
			if(text[i] == '%' && i > 0 && text[i-1] == '<') {
				uint j;
				string inside;
				
				
				int parse_condition(string inside, bool normal) {
					string var1;
					string var2;
					uint action;
					
					uint k = 0;
					auto inside_len = inside.length;
					
					//( i == 3 )
					//	^
					while(inside[k] != ' ') {
						// I know for sure that the first argument is going to be a variable. It makes no sense to say if 1 == 2 or if 1 == myvar
						if(inside[k] != '$') {
							var1 ~= inside[k];
						}
						
						if(++k >= inside_len) {
							if(var1[0] == '!') {
								action = (normal ? pnl_action_jne : pnl_action_je);
								var1 = var1[1 .. $];
							} else {
								action = (normal ? pnl_action_je : pnl_action_jne);
							}
							
							goto parse_inside;
						}
					}
					
					//( i == 3 )
					//	 ^
					while(inside[k] == ' ') {
						if(++k >= inside_len) {
							return -1;
						}
					}
					
					if(k >= inside_len-2) {
						return -1;
					}
					
					//( i == 3 )
					//	  ^^
					char a = inside[k++];
					char b = inside[k++];
					if(b == '=') {
						if(a == '=') {
							action = (normal ? pnl_action_jne : pnl_action_je);
						} else if(a == '>') {
							action = (normal ? pnl_action_jl : pnl_action_jge);
						} else if(a == '<') {
							action = (normal ? pnl_action_jg : pnl_action_jle);
						} else if(a == '!') {
							action = (normal ? pnl_action_je : pnl_action_jne);
						} else {
							inlineError("unknown conditional: '" ~ a ~ b ~ "' expr: '" ~ inside ~ "'");
							return -1;
						}
					} else if(a == '>') {
						action = (normal ? pnl_action_jle : pnl_action_jg);
					} else if(a == '<') {
						action = (normal ? pnl_action_jge : pnl_action_jl);
					} else {
						inlineError("unknown conditional: '" ~ a ~ b ~ "' expr: '" ~ inside ~ "'");
						return -1;
					}
					
					//( i == 3 )
					//		^
					while(inside[k] == ' ') {
						if(++k >= inside_len) {
							//TODO!! - add errors
							return -1;
						}
					}
					
					//( i == 3 )
					//		 ^
					while(inside[k] != ' ') {
						
						//TODO!!! parse inside of "", and '' to make sure spaces aren't found in wrong places
						
						var2 ~= inside[k];
						
						if(++k >= inside_len) {
							break;
						}
					}
					
				parse_inside:
					if(var1[0] == '$') {
						var1 = var1[1 .. $];
					}
					
					int v1_inst = find_var(var1);
					if(v1_inst >= 0) {
						uint var1_type = var_type[v1_inst][var1];
						auto var2_len = var2.length;
						
						if(!var2_len) {
							switch(var1_type) {
							case pnl_action_var_str:
								var2 = `""`;
								break;
							case pnl_action_var_uint:
							case pnl_action_var_int:
							case pnl_action_var_long:
							case pnl_action_var_ulong:
								var2 = "0";
								break;
							default:
								inlineError("malformed condition (" ~ inside ~ ')');
							}
							
							var2_len = var2.length;
						}
						
						
						if(var2[0] == '"' && var2[var2_len-1] == '"') {
							// (var == "string")
							if(var1_type == pnl_action_var_str) {
								string string = var2[1 .. var2_len-1];
								//TODO!!! - parse the string, removing escaped expressions
								PNLByte* p = newByte();
								p.action = action | pnl_action_var_str_mask;
								p.ptr_str = var_str[v1_inst][var1];
								p.ptr_str2 = getConst(string);
								return pb_count-1;
							} else {
								inlineError("incorrect types for comparison: A string can only be compared with a string " ~ Integer.toString(var1_type));
							}
						} else if((var2[0] >= '0' && var2[0] <= '9') || var2[0] == '-') {
							// (var == 0)
							int number = toInt(var2);
							
							PNLByte* p = newByte();
							p.action = action;
							p.ptr = var_ptr[v1_inst][var1];
							p.value = number;
							
							return pb_count-1;
						} else {
							// (var == var2)
							if(var2[0] == '$') {
								var2 = var2[1 .. $];
							}
							
							int v2_inst = find_var(var2);
							if(v2_inst >= 0) {
								PNLByte* p = newByte();
								if(var_type[v1_inst][var1] == pnl_action_var_str && var_type[v2_inst][var2] == pnl_action_var_str) {
									p.action = action | pnl_action_var_str_mask;
									p.ptr_str = var_str[v1_inst][var1];
									p.ptr_str2 = var_str[v2_inst][var2];
								} else {
									p.action = action | pnl_action_var_int_mask;
									p.ptr = var_ptr[v1_inst][var1];
									p.ptr2 = var_ptr[v2_inst][var2];
								}
								
								return pb_count-1;
							}
						}
					} else {
						int v1_func_inst = find_func(var1);
						if(v1_func_inst >= 0) {
							// not a variable... try a function
							PNLByte* p = newByte();
							p.action = action | pnl_action_func_mask;
							p.ptr = cast(char*)&obj_funcs[var1][v1_func_inst];
							//TODO!!!! - set this to the internal values
							p.str_value = null;
							return pb_count-1;
							
						} else {
							inlineError("could not find variable or function '" ~ var1 ~ "' inside: '" ~ inside ~ "'");
						}
					}
					
					return -1;
				}
				
				
				// PARSE_CONDITION
				/*
				
				if var1 == var2 && var1 != var3
				
				cmp var1, var2
				jne L9>
				cmp var1, var3
				je L9>
					code
			L9:	
			
				if (var1 == var2 && var1 != var3) || (var2 == var3)
				
				cmp var1, var2
				jne L1>
				cmp var1, var3
				je L1>
				jmp L2>
			L1:	cmp var2, var3
				jne L9>
			L2:		code
			L9:	
				
			AND:
				cmp condition1
				jne outside expression
				cmp condition2
				jne outside expression
					inside expression
				outside expression
			
			OR:
				cmp condition1
				je inside expression
				cmp condition2
				je inside expression
				jmp outside (save)
					inside expression
				outside expression
			
				*/
				
				struct cond_ret {
					int[] inside_jmps;
					int[] outside_jmps;
					bool is_and;
				}
				
				cond_ret parse_conditions(string inside) {
					cond_ret ret;
					bool is_and = true;
					string[] exprs = expressions(inside, is_and);
					if(exprs.length == 1) {
						is_and = true;
					}
					
					ret.is_and = is_and;
					
					foreach(string str; exprs) {
						if(str[0] == '(') {
							bool cond_and;
							int outside;
							auto l = parse_conditions(str);
							if(cond_and == true && is_and == true) {
								// another save...
								//saves ~= l;
							} else if(cond_and == true && is_and == false) {
								//pb_count-1
								//foreach(j; l) {
								//	(*pb[c_jump]).new_location = pb_count-1;
								//}
							} else if(cond_and == false && is_and == true) {
								// (condition1 && (condition2 || condition3) && condition4
								ret.outside_jmps ~= l.outside_jmps;
								
								if(l.is_and == false) {
									// add jump byte
									PNLByte* p = newByte();
									p.action = pnl_action_jmp;
									ret.outside_jmps ~= pb_count-1;
								}
							} else {
								// BAD LOGIC... should be simplifed in a different step
							}
							
							foreach(j; l.inside_jmps) {
								(*pb[j]).new_location = pb_count;
							}
						} else {
							int l = parse_condition(str, is_and);
							if(l >= 0) {
								if(is_and == true) {
									ret.outside_jmps ~= l;
								} else {
									ret.inside_jmps ~= l;
								}
							}
						}
					}
					
					return ret;
				}
				
				text_end = i-1;
				// if you update this code, don't forget to update it at the end of the for-loop as well
				if(first_text == true && text[text_start] == ' ') {
					text_start++;
				}
				
				if(text_start != text_end) { // && text_start != text_end-1
					//if(allow_space == false && text[text_end-1] == ' ' && (text_end-text_start == 1 || pb_count != 0)) {
					//	  text_end--;
					//}
					
					PNLByte* p = newByte();
					p.action = pnl_action_text;
					p.ptr_start = text_start;
					p.ptr_end = text_end;
					first_text = false;
				}
				
				j = ++i;
				
				string cmd;
				while(true) {
					if(text[i] == '%' && text[i+1] == '>') {
						cmd = trim(text[j .. i]);
						break;
					} else {
						if(text[i] == ' ') {
							cmd = trim(text[j .. i]);
						} else if(i > 2 && text[i-1] == '=' && text[i-2] == '%' && text[i-3] == '<') {
							cmd = "=";
						} 
						
						if(cmd.length) {
							//get the inside
							while(!(text[i] == '%' && text[i+1] == '>')) {
								inside ~= text[i];
								
								if(++i >= text_len) {
									goto inside_error;
								}
							}
							
							inside = trim(inside);
							break;
						}
					}
					
					if(++i >= text_len) {
						inlineError("unmatched '<%'");
						goto return_normal;
					}
				}
				
				i+=2; // skip the %>
				if(cmd != "=") {
					if(cmd == "if") {
						start_new_scope = false;
						just_if = true;
						auto l = parse_conditions(inside);
						if(l.outside_jmps.length || l.inside_jmps.length) {
							if(l.is_and == false) {
								PNLByte* p = newByte();
								p.action = pnl_action_jmp;
								condition_jump ~= pb_count-1;
							}
							
							condition_jump ~= l.outside_jmps;
							foreach(c_jump; l.inside_jmps) {
								(*pb[c_jump]).new_location = pb_count;
							}
							
							i = parse_indent(i);
						} else {
							inlineError("unknown conditional for if '" ~ inside ~ "'");
						}
					} else if(cmd == "elseif") {
						just_if = true;
						if(start_new_scope == true) 
							goto return_text_end;
						
						PNLByte* p = newByte();
						p.action = pnl_action_jmp;
						jmp_list ~= &p.new_location;
						
						auto l = parse_conditions(inside);
						if(l.outside_jmps.length) {
							if(condition_jump.length) {
								foreach(c_jump; l.inside_jmps) {
									(*pb[c_jump]).new_location = pb_count-1;
								}
								
								foreach(c_jump; condition_jump) {
									(*pb[c_jump]).new_location = pb_count-1; // eq l ???
									condition_jump = l.outside_jmps;
								}
								
								//TODO!!! - write a unittest for this
								/*if(l.is_and == false) {
									PNLByte* p = newByte();
									p.action = pnl_action_jmp;
									condition_jump ~= pb_count-1;
								}*/
							}
							
							i = parse_indent(i);
						} else {
							inlineError("unknown conditional for elseif '" ~ inside ~ "'");
						}
					} else if(cmd == "else") {
						just_if = false;
						if(start_new_scope == true)
							goto return_text_end;
						
						PNLByte* p = newByte();
						p.action = pnl_action_jmp;
						jmp_list ~= &p.new_location;
						
						if(condition_jump.length) {
							foreach(c_jump; condition_jump) {
								(*pb[c_jump]).new_location = pb_count;
							}
							
							condition_jump = null;
						}
						
						i = parse_indent(i);
						
					} else if(cmd == "endif") {
						if(start_new_scope == true)
							goto return_text_end;
						
						start_new_scope = true;
						if(condition_jump.length) {
							foreach(c_jump; condition_jump) {
								(*pb[c_jump]).new_location = (just_if ? pb_count : pb_count-1);
							}
							
							condition_jump = null;
						}
						
						just_if = false; 
						
						auto jmp_len = jmp_list.length;
						//foreach(k; 0 .. jmp_len) {
						for(uint k = 0; k < jmp_len; k++) {
							*jmp_list[k] = pb_count;
						}
						
						jmp_list.length = 0;
					} else if(cmd == "load" || cmd == "loop") {
						// make an array of pointers to the variables (it must be a variable, not a literal, for now)
						// pass it to the new_object()
						
						uint ii = 0;
						auto itext_len = inside.length;
						
						uint is_params = true;
						while(inside[ii] != '{') {
							if(++ii >= itext_len) {
								is_params = false;
								break;
							}
						}
						
						string[string] options;
						string[string] params = null;
						if(is_params == true) {
							params.parse_options(inside[ii .. $]);
							inside = trim(inside[0 .. ii]);
						}
						
						void delegate() ee = new_object(this, inside, params);
						if(ee) {
							PNLByte* p = newByte();
							p.action = pnl_action_void_delegate;
							p.dg = ee;
						}
						
						if(cmd == "loop") {
							start_new_scope = false;
							if(inside.length) {
								int loop_inst = find_loop(inside);
								if(loop_inst >= 0) {
									PNLByte* p = newByte();
									p.action = pnl_action_loop;
									p.ptr = cast(char*)&obj_loops[inside][loop_inst];
									
									loop_return = pb_count-1;
									
									i = parse_indent(i);
								}
							}
						}
					} else if(cmd == "endloop") {
						if(start_new_scope == true)
							goto return_text_end;
						
						start_new_scope = true;
						if(loop_return >= 0) {
							PNLByte* p = newByte();
							p.action = pnl_action_jmp;
							p.new_location = loop_return;
							(*pb[loop_return]).new_location = pb_count;
							loop_return = -1;
						} else {
							inlineError("no loop to return");
						}
					} else if(cmd == "variable") {
						if(inside.length) {
							uint vtype = pnl_action_var_uint;
							string[string] options;
							string vname;
							string vdefault;
							
							options.parse_options(inside);
							
							val = "name" in options;
							if(val) {
								vname = *val;
								
								val = "type" in options;
								if(val) {
									if(*val == "uint") {
										vtype = pnl_action_var_uint;
									} else if(*val == "int") {
										vtype = pnl_action_var_int;
									} else if(*val == "long") {
										vtype = pnl_action_var_long;
									} else if(*val == "ulong") {
										vtype = pnl_action_var_ulong;
									} else if(*val == "string") {
										vtype = pnl_action_var_str;
									} else {
										inlineError("variable '" ~ vname ~ "' has unrecognized type; using uint by default");
									}
								}
								
								char* var;
								string* svar;
								if(vtype == pnl_action_var_uint) {
									var = cast(char*)getGlobalUint(vname);
								} else if(vtype == pnl_action_var_int) {
									var = cast(char*)getGlobalInt(vname);
								} else if(vtype == pnl_action_var_long) {
									var = cast(char*)getGlobalLong(vname);
								} else if(vtype == pnl_action_var_ulong) {
									var = cast(char*)getGlobalUlong(vname);
								} else if(vtype == pnl_action_var_str) {
									svar = getGlobalStr(vname);
								}
								
								val = "default" in options;
								if(val) {
									vdefault = *val;
									
									if(vtype == pnl_action_var_uint) {
										*cast(uint*)var = toUint(vdefault);
									} else if(vtype == pnl_action_var_int) {
										*cast(int*)var = toInt(vdefault);
									} else if(vtype == pnl_action_var_long) {
										*cast(long*)var = toLong(vdefault);
									} else if(vtype == pnl_action_var_ulong) {
										*cast(ulong*)var = toUlong(vdefault);
									} else if(vtype == pnl_action_var_str) {
										*svar = vdefault;
									}
								
									if(vdefault.length && vdefault[0] == '$') {
										vdefault = vdefault[1 .. $];
										int v_inst = find_var(vdefault);
										if(v_inst >= 0) {
											if(vtype == var_type[v_inst][vdefault]) {
												PNLByte* p = newByte();
												if(vtype == pnl_action_var_str) {
													p.action = pnl_action_set_var_str;
													p.ptr_str2 = var_str[v_inst][vdefault];
													p.ptr_str = svar;
												} else {
													if(vtype == pnl_action_var_uint || vtype == pnl_action_var_int) {
														p.action = pnl_action_set_var_uint;
													} else if(vtype == pnl_action_var_uint || vtype == pnl_action_var_int) {
														p.action = pnl_action_set_var_uint;
													} else {
														errorln("I dunno the type of your variable");
													}
													
													p.ptr2 = var_ptr[v_inst][vdefault];
													p.ptr = var;
												}
											} else {
												removeByte();
												inlineError("ERROR: mismatched types for '" ~ *val ~"' and '$" ~ vdefault ~ "'");
											}
										} else {
											removeByte();
											inlineError("ERROR: could not find var '" ~ *val ~ "'");
										}
									}
								}
							} else {
								inlineError("variable must have a name!");
							}
						}
					} else if(cmd == "set") {
						if(inside.length) {
							string[string] options;
							string vname;
							uint vtype = pnl_action_var_uint;
							
							options.parse_options(inside);
							
							val = "name" in options;
							if(val) {
								vname = *val;
								
								int v_inst = find_var(vname);
								if(v_inst >= 0) {
									uint v_type = var_type[v_inst][vname];
									
									val = "value" in options;
									if(val) {
										PNLByte* p = newByte();
										string value = *val;
										if(value.length && value[0] == '$') {
											value = value[1 .. $];
											int v_inst2 = find_var(value);
											if(v_inst2 >= 0) {
												uint v_type2 = var_type[v_inst2][value];
												if(v_type2 == pnl_action_var_str) {
													p.action = pnl_action_set_var_str;
												} else if(v_type2 == pnl_action_var_int || v_type2 == pnl_action_var_uint) {
													p.action = pnl_action_set_var_uint;
												} else if(v_type2 == pnl_action_var_long || v_type2 == pnl_action_var_ulong) {
													p.action = pnl_action_set_var_ulong;
												}
												
												p.ptr2 = var_ptr[v_inst2][value];
												p.ptr = cast(char*)var_ptr[v_inst][vname];
											} else {
												removeByte();
												inlineError("ERROR: could not find var '" ~ *val ~ "'");
											}
										} else {
											if(v_type == pnl_action_var_uint) {
												p.action = pnl_action_set_uint;
												p.ptr = cast(char*)var_ptr[v_inst][vname];
												p.value = toUint(value);
											} else if(v_type == pnl_action_var_int) {
												p.action = pnl_action_set_int;
												p.ptr = cast(char*)var_ptr[v_inst][vname];
												p.value = cast(uint)toInt(value);
											} else if(v_type == pnl_action_var_long) {
												p.action = pnl_action_set_long;
												p.ptr = cast(char*)var_ptr[v_inst][vname];
												p.long_value = cast(long)toLong(value);
											} else if(v_type == pnl_action_var_ulong) {
												p.action = pnl_action_set_ulong;
												p.ptr = cast(char*)var_ptr[v_inst][vname];
												p.ulong_value = toUlong(value);
											} else if(v_type == pnl_action_var_str) {
												p.action = pnl_action_set_str;
												p.ptr = cast(char*)var_str[v_inst][vname];
												p.str_value = value;
											}
										}
									}
								} else {
									inlineError("variable '" ~ vname ~ "' could not be found\nYou probably forgot to define it with the variable template");
								}
							} else {
								inlineError("variable must have a name!");
							}
						}
					} else if(cmd == "final") {
						if(inside.length) {
							if(inside[0] == '$') {
								inside = inside[1 .. $];
							}
							
							int v_inst = find_var(inside);
							if(v_inst >= 0) {
								uint v_type = var_type[v_inst][inside];
								
								if(v_type == pnl_action_var_str) {
									PNLByte* p = newByte();
									p.action = pnl_action_final_replace;
									p.ptr_str = var_str[v_inst][inside];
								} else {
									inlineError("variable '" ~ inside ~ "' must be of type string");
								}
							} else {
								inlineError("variable '" ~ inside ~ "' could not be found\nYou probably forgot to define it with the variable template");
							}
						}
					} else if(cmd == "frame" || cmd == "panel") {
						debug {
							if(cmd == "panel") {
								inlineError("the directive 'panel' has been deprecated");
							}
						}
						
						if(inside.length) {
							string[string] options;
							
							options.parse_options(inside);
							
							val = "name" in options;
							if(val) {
								string pnl_name = *val;
								
								PANELS ~= new TemplateFrame(pnl_name);
								TemplateFrame* tp = &PANELS[$ - 1];
								panels ~= tp;
								
								val = "default" in options;
								bool still_need_default = true;
								if(val) {
									string s_def = *val;
									tp.default_panel_str = s_def;
									PNL* def = (s_def in PNL.pnl);
									if(def) {
										tp.default_panel = def;
									}
								}
								
								val = "hidden" in options;
								if(val) {
									tp.hidden = true;
								}
								
								PNLByte* p = newByte();
								p.action = pnl_action_panel;
								p.dg = &tp.render;
							} else {
								inlineError("panel must have a name");
							}
						}
					} else {
						if(cmd == "xml") {
							// for the tag: <?xml version="1.0" encoding="utf-8" ?>
							text[text_start+1] = '?';
							text[i-2] = '?';
							continue;
						} else if(cmd in templates) {
							void function(inout PNL pnl, string cmd, string inside) pp = templates[cmd];
							pp(this, cmd, inside);
						} else {
							int v_inst = find_var(cmd);
					
							if(v_inst >= 0) {
								PNLByte* p = newByte();
								p.action = var_type[v_inst][cmd];
								p.ptr = var_ptr[v_inst][cmd];
							} else {
								inlineError("variable '" ~ cmd ~ "' is not registered or unrecognized command");
							}
						}
					}
				} else {
					size_t pos = find_c(inside, ' ');
					string[string] opts;
					string params;
					if(pos != -1) {
						params = inside[cast(size_t)pos+1 .. $];
						opts.parse_options(params);
						inside = inside[0 .. cast(size_t)pos];
					}
					
					if(inside[0] == '$') {
						inside = inside[1 .. $];
					}
					
					int v_inst;
					PNLByte* p = newByte();
					if((v_inst = find_func(inside)) >= 0) {
						p.action = pnl_action_func_mask;
						p.str_value = params;
						p.ptr = cast(char*)&obj_funcs[inside][v_inst];
					} else if((v_inst = find_var(inside)) >= 0) {
						first_text = false;
						
						p.action = var_type[v_inst][inside];
						if(p.action == pnl_action_var_str) {
							p.ptr_str = var_str[v_inst][inside];
						} else {
							p.ptr = var_ptr[v_inst][inside];
						}
						
						val = "truncate" in opts;
						if(val) {
							p.truncate = toUint(*val);
						}
						
						val = "transform" in opts;
						if(val) {
							p.truncate = ~p.truncate;
						}
						
						val = "parse" in opts;
						if(val) {
							void function(string input)* ptr_callback = *val in text_transforms;
							if(ptr_callback) {
								p.callback = *ptr_callback;
							} else {
								inlineError("could not find requested text parser: " ~ *val);
							}
						}
					} else {
						removeByte();
						inlineError("variable '" ~ inside ~ "' is not registered");
					}
				}
				
			inside_error:
				text_start = i;
			}
		}
		
		if(loop_return != -1) {
			errorln("YOU HAVE AN UNENDED (infinite) LOOP...");
			//TODO!!!! - this doesn't prevent the loop from becoming infinite...
			// search back to the loop and reset that byte
		}
		
		if(start_char == 0) {
			text_end = i;
			
			if(text_start != text_end && text_start != text_end-1) {
				if(text[text_end-1] == ' ' && (text_end-text_start == 1 || pb_count != 0)) {
					text_end--;
				}
				
				PNLByte* p = newByte();
				p.action = pnl_action_text;
				p.ptr_start = text_start;
				p.ptr_end = text_end;
			}
		}
		
	return_normal:
		scopee--;
		return i;
		
	return_text_end:
		scopee--;
		return text_end;
	}
	
	// I wonder if life sucks being a pornstar.. I mean, she wakes up in the morning and thinks to herself... I've rode the most "primo-dong" of all time, but I need something more... and she probably doesn't enjoy the quality near as much as we think she would.
	// I wonder if they contemplate that there's something better than sex, considering they have it so much more often, so it probably isn't as fulfilling.
	
	version(testbytecode) {
		static bool finished_print_bytecode = false;
		void print_bytecode() {
			ulong len = pb.length;
			uint i = 0;
			while(i < len) {
				uint cur = i;
				PNLByte* p = pb[i++];
				switch(p.action) {
					case pnl_action_text:
						noticeln(cur, ": prt(Text) '", trim(text[p.ptr_start .. p.ptr_end]), "'");
					break;
					case pnl_action_var_float:
						noticeln(cur, ": prt(float) '", *cast(float*)p.ptr, "'");
					break;
					case pnl_action_var_uint:
						noticeln(cur, ": prt(uint) '", *cast(uint*)p.ptr, "'");
					break;
					case pnl_action_var_int:
						noticeln(cur, ": prt(int) '", *cast(int*)p.ptr, "'");
					break;
					case pnl_action_var_ulong:
						noticeln(cur, ": prt(ulong) '", *cast(ulong*)p.ptr, "'");
					break;
					case pnl_action_var_long:
						noticeln(cur, ": prt(long) '", *cast(long*)p.ptr, "'");
					break;
					case pnl_action_var_str:
						noticeln(cur, ": prt_html(string) '", *p.ptr_str, "'");
					break;
					case pnl_action_var_literal_str:
						noticeln(cur, ": prt(string) '", *p.ptr_str, "'");
					break;
					case pnl_action_je:
						noticeln(cur, ": (je) ", p.new_location);
					break;
					case pnl_action_je | pnl_action_var_str_mask:
						noticeln(cur, ": (je:(", p.ptr_str, ") (", p.ptr_str, "))" , p.new_location);
					break;
					case pnl_action_je | pnl_action_func_mask:
						noticeln(cur, ": (func:je) ", p.new_location);
					break;
					case pnl_action_je | pnl_action_var_int_mask:
						noticeln(cur, ": (var:int:je) ", p.new_location);
					break;
					case pnl_action_jne:
						noticeln(cur, ": (jne) ", p.new_location);
					break;
					case pnl_action_jne | pnl_action_var_str_mask:
						noticeln(cur, ": (jne:(", p.ptr_str, ") (", p.ptr_str, "))" , p.new_location);
					break;
					case pnl_action_jne | pnl_action_func_mask:
						noticeln(cur, ": (func:jne) ", p.new_location);
					break;
					case pnl_action_jne | pnl_action_var_int_mask:
						noticeln(cur, ": (int:jne) ", p.new_location);
					break;
					case pnl_action_jg:
						noticeln(cur, ": (jg) ", p.new_location);
					break;
					case pnl_action_jg | pnl_action_func_mask:
						noticeln(cur, ": (func:jg) ", p.new_location);
					break;
					case pnl_action_jg | pnl_action_var_int_mask:
						noticeln(cur, ": (int:jg) ", p.new_location);
					break;
					case pnl_action_jg | pnl_action_var_str_mask:
						noticeln(cur, ": (jg:(", p.ptr_str, ") (", p.ptr_str, "))" , p.new_location);
					break;
					case pnl_action_jl:
						noticeln(cur, ": (jl) ", p.new_location);
					break;
					case pnl_action_jl | pnl_action_func_mask:
						noticeln(cur, ": (func:jl) ", p.new_location);
					break;
					case pnl_action_jl | pnl_action_var_int_mask:
						noticeln(cur, ": (int:jl) ", p.new_location);
					break;
					case pnl_action_jl | pnl_action_var_str_mask:
						noticeln(cur, ": (jl:(", p.ptr_str, ") (", p.ptr_str, "))" , p.new_location);
					break;
					case pnl_action_jge:
						noticeln(cur, ": (jge) ", p.new_location);
					break;
					case pnl_action_jge | pnl_action_func_mask:
						noticeln(cur, ": (func:jge) ", p.new_location);
					break;
					case pnl_action_jge | pnl_action_var_int_mask:
						noticeln(cur, ": (int:jge) ", p.new_location);
					break;
					case pnl_action_jge | pnl_action_var_str_mask:
						noticeln(cur, ": (jge:(", p.ptr_str, ") (", p.ptr_str, "))" , p.new_location);
					break;
					case pnl_action_jle:
						noticeln(cur, ": (jle) ", p.new_location);
					break;
					case pnl_action_jle | pnl_action_func_mask:
						noticeln(cur, ": (func:jle) ", p.new_location);
					break;
					case pnl_action_jle | pnl_action_var_int_mask:
						noticeln(cur, ": (int:jle) ", p.new_location);
					break;
					case pnl_action_jle | pnl_action_var_str_mask:
						noticeln(cur, ": (jle:(", p.ptr_str, ") (", p.ptr_str, "))" , p.new_location);
					break;
					case pnl_action_jmp:
						noticeln(cur, ": (jmp) ", p.new_location);
					break;
					case pnl_action_loop:
						noticeln(cur, ": (loop) ", p.new_location);
					break;
					case pnl_action_template:
						noticeln(cur, ": (template)");
					break;
					case pnl_action_panel:
						noticeln(cur, ": (panel)");
					break;
					case pnl_action_final_replace:
						noticeln(cur, ": (final replace)");
					break;
					case pnl_action_void_function:
						noticeln(cur, ": (static load)");
					break;
					case pnl_action_void_delegate:
						noticeln(cur, ": (load)");
					break;
					default:
						noticeln(cur, ": (unknown) !!! (", p.action, ")");
				}
			}
			
			noticeln("-----------------------");
		}
	}
	
	void render() {
		//debug noticeln("rendering panel(", name, ")");
		version(renderingbytecode) noticeln("\nstarting render (", name, ")...");
		
		auto len = pb.length;
		uint i = 0;
		
		while(i < len) {
			uint cur = i;
			PNLByte* p = pb[i++];
			switch(p.action) {
				case pnl_action_text:
					version(renderingbytecode) noticeln(cur, ": prt(Text) ", " (", p.ptr_start, " ", p.ptr_end, ")");
					prt(text[p.ptr_start .. p.ptr_end]);
				break;
				case pnl_action_var_uint:
					version(renderingbytecode) noticeln(cur, ": prt(uint) '", *cast(uint*)p.ptr, "'");
					prt(Integer.toString(*cast(uint*)p.ptr));
				break;
				case pnl_action_var_int:
					version(renderingbytecode) noticeln(cur, ": prt(int) '", *cast(int*)p.ptr, "'");
					prt(Integer.toString(*cast(int*)p.ptr));
				break;
				case pnl_action_var_ulong:
					version(renderingbytecode) noticeln(cur, ": prt(ulong) '", *cast(ulong*)p.ptr, "'");
					//TODO! - this is disgusting!
					prt(Integer.toString(*cast(ulong*)p.ptr));
				break;
				case pnl_action_var_long:
					version(renderingbytecode) noticeln(cur, ": prt(long) '", *cast(long*)p.ptr, "' ", Integer.toString(*cast(long*)p.ptr));
					//prt(Integer.toString(*cast(long*)p.ptr, "x#"));
					prt(Integer.toString(*cast(long*)p.ptr));
				break;
				case pnl_action_var_literal_str:
					version(renderingbytecode) noticeln(cur, ": prt(const str) '", *p.ptr_str, "'");
					string output = *p.ptr_str;
					if(output.length) {
						prt(output);
					}
				break;
				case pnl_action_func_mask:
					version(renderingbytecode) noticeln(cur, ": ptr(func)");
					long function(string) func = cast(long function(string))*cast(long function(string)*)p.ptr;
					long val = func(p.str_value);
					prt(Integer.toString(val));
				break;
				case pnl_action_var_str:
					version(renderingbytecode) noticeln(cur, ": prt(str) '", *p.ptr_str, "'");
					string output = *p.ptr_str;
					if(output) {
						bool transform = (p.truncate < 0 ? false : true);
						int truncate = (p.truncate < 0 ? ~p.truncate : p.truncate);
						
						if(p.callback) {
							p.callback(output);
						} else {
							if(truncate > 0) {
								auto str_len = output.length;
								if(str_len > truncate) {
									if(transform) {
										prt_html(output[0 .. truncate]);
									} else {
										prt(output[0 .. truncate]);
									}
									
									prt("...");
									break;
								}
							}
							
							if(transform) {
								prt_html(output);
							} else {
								prt(output);
							}
						}
					}
				break;
				case pnl_action_void_delegate:
					version(renderingbytecode) noticeln(cur, ": (load)");
					p.dg();
				break;
				
				// JE
				case pnl_action_je | pnl_action_uint_mask:
					version(renderingbytecode) noticeln(cur, ": (jump equal (var:uint ", *cast(uint*)p.ptr, " != ", p.value, ")) -> ", p.new_location);
					if(*cast(uint*)p.ptr == p.value) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				case (pnl_action_je | pnl_action_var_int_mask):
					version(renderingbytecode) noticeln(cur, ": (jump equal (var:int ", *cast(int*)p.ptr, " != ", p.value, ")) -> ", p.new_location);
					if(*cast(int*)p.ptr == *cast(int*)p.ptr2) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				case (pnl_action_je | pnl_action_var_str_mask):
					version(renderingbytecode) noticeln(cur, ": (jump equal (string ", *p.ptr_str, " != ", *p.ptr_str2, ")) -> ", p.new_location);
					if(*p.ptr_str == *p.ptr_str2) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				case (pnl_action_je | pnl_action_func_mask):
					version(renderingbytecode) noticeln(cur, ": (jump equal (func)) ", p.new_location);
					long function(string) func = cast(long function(string))*cast(long function(string)*)p.ptr;
					if(func(p.str_value) == p.value) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				
				// JNE
				case pnl_action_jne | pnl_action_uint_mask:
					version(renderingbytecode) noticeln(cur, ": (jump not equal (var:uint ", *cast(uint*)p.ptr, " != ", p.value, ")) -> ", p.new_location);
					if(*cast(uint*)p.ptr != p.value) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				case (pnl_action_jne | pnl_action_var_int_mask):
					version(renderingbytecode) noticeln(cur, ": (jump not equal (var:int ", *cast(int*)p.ptr, " != ", p.value, ")) -> ", p.new_location);
					if(*cast(int*)p.ptr != *cast(int*)p.ptr2) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				case (pnl_action_jne | pnl_action_var_str_mask):
					version(renderingbytecode) noticeln(cur, ": (jump not equal (var:string ", *p.ptr_str, " != ", *p.ptr_str2, ")) -> ", p.new_location);
					if(*p.ptr_str != *p.ptr_str2) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				case (pnl_action_jne | pnl_action_func_mask):
					version(renderingbytecode) noticeln(cur, ": (jump not equal (func)) ", p.new_location);
					long function(string) func = cast(long function(string))*cast(long function(string)*)p.ptr;
					if(func(p.str_value) != p.value) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				
				// JG
				case (pnl_action_jg | pnl_action_uint_mask):
					version(renderingbytecode) noticeln(cur, ": (jump greater (var:uint ", *cast(uint*)p.ptr, " != ", p.value, ")) -> ", p.new_location);
					if(*cast(uint*)p.ptr > p.value) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				case (pnl_action_jg | pnl_action_int_mask):
					version(renderingbytecode) noticeln(cur, ": (jump greater (var:int ", *cast(int*)p.ptr, " != ", p.value, ")) -> ", p.new_location);
					if(*cast(int*)p.ptr > p.value) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				case (pnl_action_jg | pnl_action_func_mask):
					version(renderingbytecode) noticeln(cur, ": (jump greater (func)) ", p.new_location);
					long function(string) func = cast(long function(string))*cast(long function(string)*)p.ptr;
					if(func(p.str_value) > p.value) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				
				// JGE
				case (pnl_action_jge | pnl_action_uint_mask):
					version(renderingbytecode) noticeln(cur, ": (jump greater equal (var:uint ", *cast(uint*)p.ptr, " != ", p.value, ")) -> ", p.new_location);
					if(*cast(uint*)p.ptr >= p.value) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				case (pnl_action_jge | pnl_action_int_mask):
					version(renderingbytecode) noticeln(cur, ": (jump greater equal (var:int ", *cast(int*)p.ptr, " != ", p.value, ")) -> ", p.new_location);
					if(*cast(int*)p.ptr >= p.value) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				case (pnl_action_jge | pnl_action_func_mask):
					version(renderingbytecode) noticeln(cur, ": (jump greater equal (func)) ", p.new_location);
					long function(string) func = cast(long function(string))*cast(long function(string)*)p.ptr;
					if(func(p.str_value) >= p.value) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				
				// JL
				case (pnl_action_jl | pnl_action_uint_mask):
					version(renderingbytecode) noticeln(cur, ": (jump less (var:uint ", *cast(uint*)p.ptr, " != ", p.value, ")) -> ", p.new_location);
					if(*cast(uint*)p.ptr < p.value) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				case (pnl_action_jl | pnl_action_int_mask):
					version(renderingbytecode) noticeln(cur, ": (jump less (var:int ", *cast(int*)p.ptr, " != ", p.value, ")) -> ", p.new_location);
					if(*cast(int*)p.ptr < p.value) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				case (pnl_action_jl | pnl_action_func_mask):
					version(renderingbytecode) noticeln(cur, ": (jump less (func)) ", p.new_location);
					long function(string) func = cast(long function(string))*cast(long function(string)*)p.ptr;
					if(func(p.str_value) < p.value) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				
				// JLE
				case (pnl_action_jle | pnl_action_uint_mask):
					version(renderingbytecode) noticeln(cur, ": (jump less equal (var:uint ", *cast(uint*)p.ptr, " != ", p.value, ")) -> ", p.new_location);
					if(*cast(uint*)p.ptr <= p.value) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				case (pnl_action_jle | pnl_action_int_mask):
					version(renderingbytecode) noticeln(cur, ": (jump less equal (var:int ", *cast(int*)p.ptr, " != ", p.value, ")) -> ", p.new_location);
					if(*cast(int*)p.ptr <= p.value) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				case (pnl_action_jle | pnl_action_func_mask):
					version(renderingbytecode) noticeln(cur, ": (jump less equal (func)) ", p.new_location);
					long function(string) func = cast(long function(string))*cast(long function(string)*)p.ptr;
					if(func(p.str_value) <= p.value) {
						version(renderingbytecode) noticeln(" jumping...");
						i = p.new_location;
					}
				break;
				
				
				
				case pnl_action_jmp:
					version(renderingbytecode) noticeln(cur, ": (jmp) -> ", p.new_location);
					i = p.new_location;
				break;
				case pnl_action_loop:
					version(renderingbytecode) noticeln(cur, ": (loop) -> ", p.new_location);
					
					// don't worry, it's not as crazy as it looks... it just dereferences the pointer to the delegate
					int delegate() func = cast(int delegate())*cast(int delegate()*)p.ptr;
					// then calls it.
					if(func() == 0) {
						i = p.new_location;
					}
				break;
				case pnl_action_template:
					version(renderingbytecode) noticeln(cur, ": (template)");
					p.dg();
				break;
				case pnl_action_panel:
					version(renderingbytecode) noticeln(cur, ": (panel)");
					p.dg();
					
				break;
				case pnl_action_final_replace:
					version(renderingbytecode) noticeln(cur, ": (final replace) ", p.value);
					final_replace f;
					f.offset = out_ptr;
					f.ptr = p.ptr_str;
					final_replacements ~= f;
					
				break;
				case pnl_action_set_int:
					version(renderingbytecode) noticeln(cur, ": (setting int) '", p.value, "'");
					*cast(int*)(*cast(int*)p.ptr) = cast(int)(p.value);
				break;
				case pnl_action_set_uint:
					version(renderingbytecode) noticeln(cur, ": (setting uint) '", p.value, "'");
					*cast(uint*)p.ptr = p.value;
				break;
				case pnl_action_set_long:
					version(renderingbytecode) noticeln(cur, ": (setting long) '", p.long_value, "'");
					*cast(long*)p.ptr = cast(long)(p.long_value);
				break;
				case pnl_action_set_ulong:
					version(renderingbytecode) noticeln(cur, ": (setting ulong) '", p.long_value, "'");
					*cast(ulong*)p.ptr = p.ulong_value;
				break;
				case pnl_action_var_float:
					version(renderingbytecode) noticeln(cur, ": (float) '", *cast(float*)p.ptr, "'");
					prt(Float.toString(*cast(float*)p.ptr));
				break;
				case pnl_action_set_str:
					version(renderingbytecode) noticeln(cur, ": (setting string) '", p.str_value, "'");
					*cast(string*)p.ptr = p.str_value;
				break;
				case pnl_action_set_var_uint:
					version(renderingbytecode) noticeln(cur, ": (setting var uint) '", p.ptr2, "'");
					*cast(uint*)p.ptr = *cast(uint*)p.ptr2;
				break;
				case pnl_action_set_var_ulong:
					version(renderingbytecode) noticeln(cur, ": (setting var ulong) '", p.ptr2, "'");
					*cast(ulong*)p.ptr = *cast(ulong*)p.ptr2;
				break;
				case pnl_action_set_var_str:
					version(renderingbytecode) noticeln(cur, ": (setting var string) '", p.ptr2, "'");
					*p.ptr_str = *p.ptr_str2;
				break;
				
				default:
					if(p) {
						prt(Integer.toString(cur) ~ ": should never get here... this is invalid bytecode (" ~ Integer.toString(p.action) ~ ")");
						//throw new Exception("lala");
					} else {
						prt("null bytecode. this is very bad");
					}
			}
		}
		
		.PANELS[name] = "";
	}
}

string remove_comments(string str) {
	string output;
	auto len = output.length = str.length;
	if(len) {
		size_t i = 0;
		size_t j = 0;
		for(; i < len; i++) {
			if(str[i] == '/') {
				if(str[i] == '*') {
					while(i < len && !(str[i] == '/' && str[i-1] == '*')) {
						i++;
					}
					
					continue;
				} else if(str[i] == '/') {
					while(i < len && !(str[i] == '/' && str[i-1] == '*')) {
						i++;
					}
					
					continue;
				}
			}
			
			output[j++] = str[i];
		}
		
		return output[0 .. j];
	} else {
		return str;
	}
}

string css_optimizer(string str) {
	//TODO! make this a for-loop
	str = clean_text(str);
	str = replace_sc(str, " {", '{');
	str = replace_sc(str, "{ ", '{');
	str = replace_sc(str, " }", '}');
	str = replace_sc(str, "} ", '}');
	str = replace_sc(str, ", ", ',');
	str = replace_sc(str, ": ", ':');
	str = replace_sc(str, "; ", ';');
	str = replace_ss(str, ":0px", ":0");
	str = replace_ss(str, " 0px", " 0");
	str = replace_sc(str, ";}", '}');
	
	return str;
}

string js_optimizer(string str) {
	return str;
	/+
	//TODO! make this function a for-loop
	str = remove_s(str, "\\\n");
	str = clean_text(str);
	
	
	//TODO!! - if there are any console.log then remove them immediately
	//OPTIMIZE!! - if there is only one expression inside of { }, then erase the { }
	//TODO!! - implement JS lint
	str = replace_sc(str, " (", '(');
	str = replace_sc(str, ") ", ')');
	str = replace_sc(str, " {", '{');
	str = replace_sc(str, "{ ", '{');
	str = replace_sc(str, " }", '}');
	str = replace_sc(str, "} ", '}');
	str = replace_sc(str, "; ", ';');
	str = replace_sc(str, ": ", ':');
	str = replace_sc(str, ", ", ',');
	str = replace_sc(str, ",}", '}');
	str = replace_sc(str, ",]", ']');
	//str = replace_sc(str, ";;", ';'); // this can break for(;;) statement -- and it's really unlikely to have this
	
	str = replace_sc(str, " =", '=');
	str = replace_sc(str, " !", '!');
	str = replace_sc(str, " ?", '?');
	str = replace_sc(str, " +", '+');
	str = replace_sc(str, " -", '-');
	str = replace_sc(str, " *", '*');
	str = replace_sc(str, " /", '/');
	str = replace_sc(str, " >", '>');
	str = replace_sc(str, " <", '<');
	str = replace_sc(str, " &", '&');
	str = replace_sc(str, " |", '|');
	
	str = replace_sc(str, "= ", '=');
	str = replace_sc(str, "! ", '!');
	str = replace_sc(str, "? ", '?');
	str = replace_sc(str, "+ ", '+');
	str = replace_sc(str, "- ", '-');
	str = replace_sc(str, "* ", '*');
	str = replace_sc(str, "/ ", '/');
	str = replace_sc(str, "> ", '>');
	str = replace_sc(str, "< ", '<');
	str = replace_sc(str, "& ", '&');
	str = replace_sc(str, "| ", '|');
	
	// for reason there is a small bug with a ; on the end of the line and it messing up, if I put this after the next statements
	if(str[$-1] == ';') {
		str.length = str.length-1;
	}
	
	str = replace_sc(str, ";}", '}');
	str = remove_s(str, `\\\n`);
	str = remove_s(str, `"+"`);
	str = remove_s(str, "'+'");
	
	return str;
	+/
}

unittest {
	UNIT("panel text #1", () {
		string t = `
		<?interface panel: 'text1' ?>
		LALA
		`;
		
		PNL.parse_text(t);
		assert("text1" in PNL.pnl);
		version(testbytecode) PNL.pnl["text1"].print_bytecode;
		PNL.pnl["text1"].render();
		
		assert(out_tmp[0 .. out_ptr] == "LALA");
	});
	
	UNIT("panel text #2", () {
		string t = `
		<?interface panel:'text2' ?>
		<?load TestObject ?>
		LALA
		`;
		
		PNL.parse_text(t);
		assert("text2" in PNL.pnl);
		version(testbytecode) PNL.pnl["text2"].print_bytecode;
		PNL.pnl["text2"].render();
		
		assert(out_tmp[0 .. out_ptr] == "LALA");
	});
	
	UNIT("panel text #3", () {
		string t = `
		<?interface panel:'text3' ?>
		<?load TestObject ?>
		<!--
		LALA -->
		<?=number?><!--
		LALA -->
		`;
		
		PNL.parse_text(t);
		assert("text3" in PNL.pnl);
		version(testbytecode) PNL.pnl["text3"].print_bytecode;
		PNL.pnl["text3"].render();
		
		assert(out_tmp[0 .. out_ptr] == "7");
	});
	
	UNIT("panel text #4", () {
		string t = `
		<?interface panel:'text4' ?>
		<?load TestObject ?>
		LALA<?=number?>LALA
		`;
		
		PNL.parse_text(t);
		assert("text4" in PNL.pnl);
		version(testbytecode) PNL.pnl["text4"].print_bytecode;
		PNL.pnl["text4"].render();
		
		assert(out_tmp[0 .. out_ptr] == "LALA7LALA");
	});
	
	UNIT("panel text #5", () {
		string t = `
		<?interface panel:'text5' ?>
		<?load TestObject ?>
		<?if number?>
			LALA< ><?=number?>< >
			LALA
		<?endif?>
		< >LALA
		`;
		
		PNL.parse_text(t);
		assert("text5" in PNL.pnl);
		version(testbytecode) PNL.pnl["text5"].print_bytecode;
		PNL.pnl["text5"].render();
		
		assert(out_tmp[0 .. out_ptr] == "LALA 7 LALA LALA");
	});
	
	UNIT("panel text #6", () {
		string t = `
		<?interface panel:'text6' ?>
		<?load TestObject ?>
		LALA< >
		<?=string?>< >
		LALA
		`;
		
		PNL.parse_text(t);
		assert("text6" in PNL.pnl);
		version(testbytecode) PNL.pnl["text6"].print_bytecode;
		PNL.pnl["text6"].render();
		
		assert(out_tmp[0 .. out_ptr] == "LALA test text LALA");
	});
	
	UNIT("panel text #7", () {
		string t = `
		<?interface panel:'text7' ?>
		<?load TestObject ?>
		// LALA
		<?=number?>
		// LALA
		`;
		
		PNL.parse_text(t);
		assert("text7" in PNL.pnl);
		version(testbytecode) PNL.pnl["text7"].print_bytecode;
		PNL.pnl["text7"].render();
		
		assert(out_tmp[0 .. out_ptr] == "7");
	});
	
	UNIT("panel text #8", () {
		string t = `
		<?interface panel:'text8' ?>
		<?load TestObject ?>
		<?=string?>
		<?=string truncate: 6?>
		`;
		
		PNL.parse_text(t);
		assert("text8" in PNL.pnl);
		version(testbytecode) PNL.pnl["text8"].print_bytecode;
		PNL.pnl["text8"].render();
		
		assert(out_tmp[0 .. out_ptr] == "texttest t...");
	});
	
	UNIT("panel text #9", () {
		string t = `
		<?interface panel:'text9' ?>
		<?load TestObject ?>
		LALA
		<?=number?>
		LALA
		<?=number?> <?=number?>
		LALA
		`;
		
		PNL.parse_text(t);
		assert("text9" in PNL.pnl);
		version(testbytecode) PNL.pnl["text9"].print_bytecode;
		PNL.pnl["text9"].render();
		
		assert(out_tmp[0 .. out_ptr] == "LALA7LALA7 7LALA");
	});
	
	UNIT("panel text #10", () {
		string t = `
		<?interface panel:'text10' ?>
		<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/2000/REC-xhtml1-20000126/DTD/xhtml1-strict.dtd">
		<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
		<head>
		<meta http-equiv="Content-Type" content="application/xhtml+xml; charset=utf-8" />
			<title>testing</title>
		`;
		
		PNL.parse_text(t);
		assert("text10" in PNL.pnl);
		version(testbytecode) PNL.pnl["text10"].print_bytecode;
		PNL.pnl["text10"].render();
		
		assert(out_tmp[0 .. out_ptr] == `<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/2000/REC-xhtml1-20000126/DTD/xhtml1-strict.dtd"><html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en"><head><meta http-equiv="Content-Type" content="application/xhtml+xml; charset=utf-8" /><title>testing</title>`);
	});
	
	UNIT("if #1", () {
		string t = `
		<?interface panel:'if1' ?>
		<?load TestObject ?>
		<?if number == 5 ?>
			bad1
		<?elseif number == 6 ?>
			bad1
		<?else?>
			good1
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if1" in PNL.pnl);
		version(testbytecode) PNL.pnl["if1"].print_bytecode;
		PNL.pnl["if1"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good1");
	});
	
	UNIT("if #2", () {
		string t = `
		<?interface panel:'if2' ?>
		<?load TestObject ?>
		<?if number == 7 ?>
			good1
		<?elseif number == 6 ?>
			bad1
		<?else?>
			bad2
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if2" in PNL.pnl);
		version(testbytecode) PNL.pnl["if2"].print_bytecode;
		PNL.pnl["if2"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good1");
	});
	
	UNIT("if #3", () {
		string t = `
		<?interface panel:'if3' ?>
		<?load TestObject ?>
		<?if number == 6 ?>
			bad1
		<?elseif number == 7 ?>
			good1
		<?else?>
			bad2
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if3" in PNL.pnl);
		version(testbytecode) PNL.pnl["if3"].print_bytecode;
		PNL.pnl["if3"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good1");
	});
	
	UNIT("if #4", () {
		string t = `
		<?interface panel:'if4' ?>
		<?load TestObject ?>
		<?if number == 6 ?>
			bad1
		<?elseif number == 7 ?>
			<?if number2 == 4 ?>
				bad1
			<?else?>
				good1
			<?endif?>
		<?else?>
			bad2
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if4" in PNL.pnl);
		version(testbytecode) PNL.pnl["if4"].print_bytecode;
		PNL.pnl["if4"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good1");
	});
	
	UNIT("if #5", () {
		string t = `
		<?interface panel:'if5' ?>
		<?load TestObject ?>
		<?if number == 6 ?>
			bad1
		<?elseif number == 7 ?>
			good1
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if5" in PNL.pnl);
		version(testbytecode) PNL.pnl["if5"].print_bytecode;
		PNL.pnl["if5"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good1");
	});
	
	UNIT("if #6", () {
		string t = `
		<?interface panel:'if6' ?>
		<?load TestObject ?>
		la
		<?if number == 0 ?>
			bad1
		<?endif?>
		la
		`;
		
		PNL.parse_text(t);
		assert("if6" in PNL.pnl);
		version(testbytecode) PNL.pnl["if6"].print_bytecode;
		PNL.pnl["if6"].render();
		
		assert(out_tmp[0 .. out_ptr] == "lala");
	});
	
	UNIT("if #7", () {
		string t = `
		<?interface panel:'if7' ?>
		<?load TestObject ?>
		la
		<?if number == 7 ?>
			<?if number == 0 ?>
				bad1
			<?elseif number == 1 ?>
				bad2
			<?endif?>
		<?endif?>
		la
		`;
		
		PNL.parse_text(t);
		assert("if7" in PNL.pnl);
		version(testbytecode) PNL.pnl["if7"].print_bytecode;
		PNL.pnl["if7"].render();
		
		assert(out_tmp[0 .. out_ptr] == "lala");
	});
	
	UNIT("if #8", () {
		string t = `
		<?interface panel:'if8' ?>
		<?load TestObject ?>
		<?if number == 7 ?>
			good1
		<?elseif number == 8 ?>
			bad1
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if8" in PNL.pnl);
		version(testbytecode) PNL.pnl["if8"].print_bytecode;
		PNL.pnl["if8"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good1");
	});
	
	UNIT("if #9", () {
		string t = `
		<?interface panel:'if9' ?>
		<?load TestObject ?>
		<?=number?>
		<?if number2 == number ?>
			<?=number2?> <?=number?>
		<?else?>
			bad
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if9" in PNL.pnl);
		version(testbytecode) PNL.pnl["if9"].print_bytecode;
		PNL.pnl["if9"].render();
		
		assert(out_tmp[0 .. out_ptr] == "77 7");
	});
	
	UNIT("if #10", () {
		string t = `
		<?interface panel:'if10' ?>
		<?load TestObject ?>
		<?if number != 7 ?>
			bad1
		<?elseif number2 == number ?>
			<?=number2?> <?=number?>
		<?else?>
			bad2
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if10" in PNL.pnl);
		version(testbytecode) PNL.pnl["if10"].print_bytecode;
		PNL.pnl["if10"].render();
		
		assert(out_tmp[0 .. out_ptr] == "7 7");
	});
	
	UNIT("if #11", () {
		string t = `
		<?interface panel:'if11' ?>
		<?load TestObject ?>
		<?if testfunc_true ?>
			good
		<?else?>
			bad
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if11" in PNL.pnl);
		version(testbytecode) PNL.pnl["if11"].print_bytecode;
		PNL.pnl["if11"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good");
	});
	
	UNIT("if #12", () {
		string t = `
		<?interface panel:'if12' ?>
		<?load TestObject ?>
		<?if testfunc_false ?>
			bad1
		<?elseif testfunc_true ?>
			good
		<?else?>
			bad2
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if12" in PNL.pnl);
		version(testbytecode) PNL.pnl["if12"].print_bytecode;
		PNL.pnl["if12"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good");
	});
	
	UNIT("if #13", () {
		string t = `
		<?interface panel:'if13' ?>
		<?load TestObject ?>
		<?if empty_string ?>
			bad1
		<?else?>
			good
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if13" in PNL.pnl);
		version(testbytecode) PNL.pnl["if13"].print_bytecode;
		PNL.pnl["if13"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good");
	});
	
	UNIT("if #14", () {
		string t = `
		<?interface panel:'if14' ?>
		<?load TestObject ?>
		<?if $string && $empty_string ?>
			bad1
		<?else?>
			good
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if14" in PNL.pnl);
		version(testbytecode) PNL.pnl["if14"].print_bytecode;
		PNL.pnl["if14"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good");
	});
	
	UNIT("if #15", () {
		string t = `
		<?interface panel:'if15' ?>
		<?load TestObject ?>
		<?if $string && $string ?>
			good
		<?else?>
			bad
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if15" in PNL.pnl);
		version(testbytecode) PNL.pnl["if15"].print_bytecode;
		PNL.pnl["if15"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good");
	});
	
	UNIT("if #16", () {
		string t = `
		<?interface panel:'if16' ?>
		<?load TestObject ?>
		<?if string != "" ?>
			good
		<?else?>
			bad
		<?endif?>
		<?if string ?>
			good
		<?else?>
			bad
		<?endif?>
		<?if empty_string != "" ?>
			bad
		<?else?>
			good
		<?endif?>
		<?if empty_string ?>
			bad
		<?else?>
			good
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if16" in PNL.pnl);
		version(testbytecode) PNL.pnl["if16"].print_bytecode;
		PNL.pnl["if16"].render();
		
		assert(out_tmp[0 .. out_ptr] == "goodgoodgoodgood");
	});
	
	UNIT("if #17", () {
		string t = `
		<?interface panel:'if17' ?>
		<?load TestObject ?>
		<?if empty_string == "" ?>
			good
		<?else?>
			bad
		<?endif?>
		<?if !empty_string ?>
			good
		<?else?>
			bad
		<?endif?>
		<?if string == "" ?>
			bad
		<?else?>
			good
		<?endif?>
		<?if !$string ?>
			bad
		<?else?>
			good
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if17" in PNL.pnl);
		version(testbytecode) PNL.pnl["if17"].print_bytecode;
		PNL.pnl["if17"].render();
		
		assert(out_tmp[0 .. out_ptr] == "goodgoodgoodgood");
	});
	
	UNIT("if #18", () {
		string t = `
		<?interface panel:'if18' ?>
		<?load TestObject ?>
		<?if ($number == 5 || $number2 == 7) ?>
			good
		<?else?>
			bad
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if18" in PNL.pnl);
		version(testbytecode) PNL.pnl["if18"].print_bytecode;
		PNL.pnl["if18"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good");
	});
	
	UNIT("if #19", () {
		string t = `
		<?interface panel:'if19' ?>
		<?load TestObject ?>
		<?if $string && ($number == 7 || $number2 == 8) ?>
			good
		<?else?>
			bad
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if19" in PNL.pnl);
		version(testbytecode) PNL.pnl["if19"].print_bytecode;
		PNL.pnl["if19"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good");
	});
	
	UNIT("if #20", () {
		string t = `
		<?interface panel:'if20' ?>
		<?load TestObject ?>
		<?if ($number == 6 || $number2 == 7) ?>
			good
		<?else?>
			bad
		<?endif?>
		<?if $number == 6 || $number2 == 7?>
			good
		<?else?>
			bad
		<?endif?>
		<?if $string && ($number == 6 || $number2 == 7) ?>
			good
		<?else?>
			bad
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if20" in PNL.pnl);
		version(testbytecode) PNL.pnl["if20"].print_bytecode;
		PNL.pnl["if20"].render();
		
		assert(out_tmp[0 .. out_ptr] == "goodgoodgood");
	});
	
	UNIT("if #21", () {
		string t = `
		<?interface panel:'if21' ?>
		<?load TestObject ?>
		<?if $string && ($number == 1234 || $number2 == 1234) ?>
			bad
		<?else?>
			good
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if21" in PNL.pnl);
		version(testbytecode) PNL.pnl["if21"].print_bytecode;
		PNL.pnl["if21"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good");
	});
	
	UNIT("if #22", () {
		string t = `
		<?interface panel:'if22' ?>
		<?load TestObject ?>
		<?if $string && ($number == 1234 || $number2 == 1234) && string ?>
			bad
		<?else?>
			good
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("if22" in PNL.pnl);
		version(testbytecode) PNL.pnl["if22"].print_bytecode;
		PNL.pnl["if22"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good");
	});
	
	UNIT("vars #1", () {
		string t = `
		<?interface panel:'vars1' ?>
		<?load TestObject ?>
		<?if number == 6 ?>
			bad1
		<?elseif number == 7 ?>
			<?=number2?> <?=number?>
		<?else?>
			bad2
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("vars1" in PNL.pnl);
		version(testbytecode) PNL.pnl["vars1"].print_bytecode;
		PNL.pnl["vars1"].render();
		
		assert(out_tmp[0 .. out_ptr] == "7 7");
	});
	
	UNIT("vars #2", () {
		string t = `
		<?interface panel:'vars2' ?>
		<?variable name: "number" default: "6" ?>
		<?if number == 6 ?>
			good1
		<?elseif number == 7 ?>
			bad1
		<?else?>
			bad2
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("vars2" in PNL.pnl);
		version(testbytecode) PNL.pnl["vars2"].print_bytecode;
		PNL.pnl["vars2"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good1");
	});
	
	UNIT("vars #3", () {
		string t = `
		<?interface panel:'vars3' ?>
		<?variable name: "number" default: "6" ?>
		<?variable name: "str1" type: "string" default: "string" ?>
		<?if number == 6 ?>
			<?=str1?>
		<?elseif number == 7 ?>
			bad1
		<?else?>
			bad2
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("vars3" in PNL.pnl);
		version(testbytecode) PNL.pnl["vars3"].print_bytecode;
		PNL.pnl["vars3"].render();
		
		assert(out_tmp[0 .. out_ptr] == "string");
	});
	
	UNIT("vars #4", () {
		string t = `
		<?interface panel:'vars4' ?>
		<?variable name: "number" default: "6" ?>
		<?if number == 6 ?>
			good
		<?elseif number == 7 ?>
			bad1
		<?else?>
			bad2
		<?endif?>
		<?set name: "number" value: "5" ?>
		<?=number?>
		`;
		
		PNL.parse_text(t);
		assert("vars4" in PNL.pnl);
		version(testbytecode) PNL.pnl["vars4"].print_bytecode;
		PNL.pnl["vars4"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good5");
	});
	
	UNIT("vars #5", () {
		string t = `
		<?interface panel:'vars5' ?>
		<?variable name: "number1" default: "6" ?>
		<?variable name: "number2" default: "7" ?>
		<?if number1 == 6 ?>
			good
		<?elseif number1 == 7 ?>
			bad1
		<?else?>
			bad2
		<?endif?>
		<?set name: "number1" value: "$number2" ?>
		<?=number1?>
		`;
		
		PNL.parse_text(t);
		assert("vars5" in PNL.pnl);
		version(testbytecode) PNL.pnl["vars5"].print_bytecode;
		PNL.pnl["vars5"].render();
		
		assert(out_tmp[0 .. out_ptr] == "good7");
	});
	
	UNIT("vars #6", () {
		string t = `
		<?interface panel:'vars6' ?>
		<?variable name: "teststr" default: "<html>" type: string ?>
		<?=teststr truncate: 4 ?>
		`;
		
		PNL.parse_text(t);
		assert("vars6" in PNL.pnl);
		version(testbytecode) PNL.pnl["vars6"].print_bytecode;
		PNL.pnl["vars6"].render();
		
		assert(out_tmp[0 .. out_ptr] == "&lt;htm...");
	});
	
	UNIT("vars #7", () {
		string t = `
		<?interface panel:'vars7' ?>
		<?variable name: "teststr" default: "<html>" type: string ?>
		<?=teststr truncate: 4 transform: none ?>
		`;
		
		PNL.parse_text(t);
		assert("vars7" in PNL.pnl);
		version(testbytecode) PNL.pnl["vars7"].print_bytecode;
		PNL.pnl["vars7"].render();
		
		assert(out_tmp[0 .. out_ptr] == "<htm...");
	});
	
	UNIT("utf-8 #1", () {
		string t = `
		<?interface panel:'utf8-1' ?>
		this is a utf-8 string: éüñäí
		`;
		
		PNL.parse_text(t);
		assert("utf8-1" in PNL.pnl);
		PNL.pnl["utf8-1"].render();
		
		assert(out_tmp[0 .. out_ptr] == "this is a utf-8 string: éüñäí");
	});
	
	UNIT("utf-8 #2", () {
		string t = `
		<?interface panel:'utf8-2' ?>
		<?variable name: "str1" type: "string" default: "éüñäí" ?>
		<?=str1?>
		`;
		
		PNL.parse_text(t);
		assert("utf8-2" in PNL.pnl);
		version(testbytecode) PNL.pnl["utf8-2"].print_bytecode;
		PNL.pnl["utf8-2"].render();
		
		assert(out_tmp[0 .. out_ptr] == "éüñäí");
	});
	
	UNIT("utf-8 #3", () {
		string t = `
		<?interface panel:'utf8-3' ?>
		<?variable name: "str1" type: "string" default: "éüñäí" ?>
		<?=str1 truncate: 2?>
		`;
		
		PNL.parse_text(t);
		assert("utf8-3" in PNL.pnl);
		version(testbytecode) PNL.pnl["utf8-3"].print_bytecode;
		PNL.pnl["utf8-3"].render();
		
		assert(out_tmp[0 .. out_ptr] == "éü");
	});
	
	UNIT("loop #1", () {
		string t = `
		<?interface panel:'loop1' ?>
		<?load TestObject ?>
		<?if number == 6 ?>
			bad1
		<?elseif number == 7 ?>
			<?loop testloop ?>
				<?=loop_current?> <?=number?>< >
			<?endloop?>
		<?else?>
			bad2
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("loop1" in PNL.pnl);
		version(testbytecode) PNL.pnl["loop1"].print_bytecode;
		PNL.pnl["loop1"].render();
		
		assert(out_tmp[0 .. out_ptr] == "0 7 1 7 2 7 3 7 4 7 5 7 6 7 7 7 ");
	});
	
	UNIT("loop #2", () {
		string t = `
		<?interface panel:'loop2' ?>
		<?load TestObject ?>
		<?if number == 6 ?>
			bad1
		<?elseif number == 7 ?>
			<?loop testloop ?>
				<?=loop_current?> <?=number?>
			<?endloop?>
		<?else?>
			bad2
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("loop2" in PNL.pnl);
		version(testbytecode) PNL.pnl["loop2"].print_bytecode;
		PNL.pnl["loop2"].render();
		
		assert(out_tmp[0 .. out_ptr] == "0 71 72 73 74 75 76 77 7");
	});
	
	UNIT("loop #3", () {
		string t = `
		<?interface panel:'loop3' ?>
		<?load TestObject ?>
		<?if number == 6 ?>
			bad1
		<?elseif number == 7 ?>
			<?loop testloop ?>
				<b><?=loop_current?> <?=number?></b>
			<?endloop?>
		<?else?>
			bad2
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("loop3" in PNL.pnl);
		version(testbytecode) PNL.pnl["loop3"].print_bytecode;
		PNL.pnl["loop3"].render();
		
		assert(out_tmp[0 .. out_ptr] == "<b>0 7</b><b>1 7</b><b>2 7</b><b>3 7</b><b>4 7</b><b>5 7</b><b>6 7</b><b>7 7</b>");
	});
	
	UNIT("loop #4", () {
		string t = `
		<?interface panel:'loop4' ?>
		<?load TestObject ?>
		<?if number == 6 ?>
			bad1
		<?elseif number == 7 ?>
			<?loop testloop ?>
				<?=loop_text?>
			<?endloop?>
		<?else?>
			bad2
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("loop4" in PNL.pnl);
		version(testbytecode) PNL.pnl["loop4"].print_bytecode;
		PNL.pnl["loop4"].render();
		
		assert(out_tmp[0 .. out_ptr] == "zeroonetwothreefourfivesixseven");
	});
	
	UNIT("loop #5", () {
		string t = `
		<?interface panel:'loop5' ?>
		<?load TestObject ?>
		<table>
			<?loop testloop ?>
				<?if loop_column == 0 ?>
					<tr>
				<?endif?>
					<td>
					<table>
						<tr>
							<td><?=loop_text?></td>
						</tr>
					</table>
					</td>
				<?if loop_column == 3 ?>
					</tr>
				<?endif?>
			<?endloop?>
		</table>
		`;
		
		PNL.parse_text(t);
		assert("loop5" in PNL.pnl);
		version(testbytecode) PNL.pnl["loop5"].print_bytecode;
		PNL.pnl["loop5"].render();
		
		assert(out_tmp[0 .. out_ptr] == "<table><tr><td><table><tr><td>zero</td></tr></table></td><td><table><tr><td>one</td></tr></table></td><td><table><tr><td>two</td></tr></table></td><td><table><tr><td>three</td></tr></table></td></tr><tr><td><table><tr><td>four</td></tr></table></td><td><table><tr><td>five</td></tr></table></td><td><table><tr><td>six</td></tr></table></td><td><table><tr><td>seven</td></tr></table></td></table>");
	});
	
	UNIT("loop #6", () {
		string t = `
		<?interface panel:'loop6' ?>
		1
		<?load TestObject ?>
		<?if number == 6 ?>
			bad1
		<?elseif number == 7 ?>
			:<?loop testloop ?>
				<?=loop_current?> <?=number?>
			<?endloop?>
		<?else?>
			bad2
		<?endif?>
		2
		<?load TestObject ?>
		<?if number == 6 ?>
			bad1
		<?elseif number == 7 ?>
			:<?loop testloop ?>
				<?=loop_current?> <?=number?>
			<?endloop?>
		<?else?>
			bad2
		<?endif?>
		`;
		
		PNL.parse_text(t);
		assert("loop6" in PNL.pnl);
		version(testbytecode) PNL.pnl["loop6"].print_bytecode;
		PNL.pnl["loop6"].render();
		
		assert(out_tmp[0 .. out_ptr] == "1:0 71 72 73 74 75 76 77 72:0 71 72 73 74 75 76 77 7");
	});
	
	UNIT("functions #1", () {
		string t = `
		<?interface func: "testfunc" ?>
		hello
		`;
		
		string t2 = `
		<?interface panel: 'functions1' ?>
		before< >
		<?call func: "testfunc" ?>< >
		after
		`;
		
		PNL.parse_text(t, true);
		PNL.parse_text(t2);
		assert("functions1" in PNL.pnl);
		version(testbytecode) PNL.pnl["functions1"].print_bytecode;
		PNL.pnl["functions1"].render();
		assert(out_tmp[0 .. out_ptr] == `before hello after`);
		
	});
	
	UNIT("functions #2", () {
		string t = `
		<?interface func: "testfunc" ?>
		hello
		`;
		
		string t2 = `
		<?interface panel: 'functions2' ?>
		<?load TestObject ?>
		before< >
		<?loop testloop ?>
			<?call func: "testfunc" ?>< >
		<?endloop?>
		after
		`;
		
		PNL.parse_text(t, true);
		PNL.parse_text(t2);
		assert("functions2" in PNL.pnl);
		version(testbytecode) PNL.pnl["functions2"].print_bytecode;
		PNL.pnl["functions2"].render();
		assert(out_tmp[0 .. out_ptr] == `before hello hello hello hello hello hello hello hello after`);
	});
	
	UNIT("functions #3", () {
		string t = `
		<?interface func: "testfunc" ?>
		<%=this.current%>:<?=this.text?>
		`;
		
		string t2 = `
		<?interface panel: 'functions3' ?>
		<?load TestObject ?>
		<?loop testloop ?>
			<?call func: "testfunc" args: {current: $loop_current, text: $loop_text} ?>< >
		<?endloop?>
		`;
		
		PNL.parse_text(t, true);
		PNL.parse_text(t2);
		assert("functions3" in PNL.pnl);
		version(testbytecode) PNL.pnl["functions3"].print_bytecode;
		PNL.pnl["functions3"].render();
		assert(out_tmp[0 .. out_ptr] == `0:zero 1:one 2:two 3:three 4:four 5:five 6:six 7:seven `);
	});
	
	UNIT("link functions #1", () {
		PNL.exportFunction("test_function", cast(int function())0);
		string t = `
		<?interface panel:'functions1' ?>
		<?load TestObject ?>
		<?link panels: { j: "profile", k: "invite" } func: "test_function" class: "custom" ?>
		`;
		
		PNL.parse_text(t);
		assert("functions1" in PNL.pnl);
		version(testbytecode) PNL.pnl["functions1"].print_bytecode;
		PNL.pnl["functions1"].render();
		
		assert(out_tmp[0 .. out_ptr] == `<a onclick="return z('k:invite,j:profile','','test_function')" href="?z=k:invite,j:profile&f=test_function" class="custom">` ||
			out_tmp[0 .. out_ptr] == `<a onclick="return z('j:profile,k:invite','','test_function')" href="?z=j:profile,k:invite&f=test_function" class="custom">`);
		
		PNL.funcs.remove("test_function");
	});
	
	UNIT("link functions #2", () {
		PNL.exportFunction("test_function", cast(int function())0);
		string t = `
		<?interface panel:'functions2' ?>
		<?load TestObject ?>
		<?link panels: { j: "profile", k: "invite" } func: "test_function" func_args: { uid: 11 } class: "custom" ?>
		`;
		
		PNL.parse_text(t);
		assert("functions2" in PNL.pnl);
		version(testbytecode) PNL.pnl["functions2"].print_bytecode;
		PNL.pnl["functions2"].render();
		
		assert(out_tmp[0 .. out_ptr] == `<a onclick="return z('k:invite,j:profile','','test_function','f_uid=11')" href="?z=k:invite,j:profile&f_uid=11&f=test_function" class="custom">` ||
			out_tmp[0 .. out_ptr] == `<a onclick="return z('j:profile,k:invite','','test_function','f_uid=11')" href="?z=j:profile,k:invite&f_uid=11&f=test_function" class="custom">`);
		
		PNL.funcs.remove("test_function");
	});
	
	UNIT("link functions #3", () {
		PNL.exportFunction("test_function", cast(int function())0);
		string t = `
		<?interface panel:'functions3' ?>
		<?load TestObject ?>
		<?link panels: { j: "profile", k: "invite" } func: "test_function" func_args: { uid: $number } class: "custom" ?>
		`;
		
		PNL.parse_text(t);
		assert("functions3" in PNL.pnl);
		version(testbytecode) PNL.pnl["functions3"].print_bytecode;
		PNL.pnl["functions3"].render();
		
		assert(out_tmp[0 .. out_ptr] == `<a onclick="return z('k:invite,j:profile','','test_function','f_uid=7')" href="?z=k:invite,j:profile&f_uid=7&f=test_function" class="custom">` ||
			out_tmp[0 .. out_ptr] == `<a onclick="return z('j:profile,k:invite','','test_function','f_uid=7')" href="?z=j:profile,k:invite&f_uid=7&f=test_function" class="custom">`);
		
		PNL.funcs.remove("test_function");
	});
	
	UNIT("link functions #4", () {
		PNL.exportFunction("test_function", cast(int function())0);
		string t = `
		<?interface panel:'functions4' ?>
		<?load TestObject ?>
		<?link panels: { j: "profile", k: "invite" } args: {uid: $number} func: "test_function" func_args: { uid: $number } class: "custom" ?>
		`;
		
		PNL.parse_text(t);
		assert("functions4" in PNL.pnl);
		version(testbytecode) PNL.pnl["functions4"].print_bytecode;
		PNL.pnl["functions4"].render();
		
		assert(out_tmp[0 .. out_ptr] == `<a onclick="return z('k:invite,j:profile','uid=7','test_function','f_uid=7')" href="?z=k:invite,j:profile&uid=7&f_uid=7&f=test_function" class="custom">` ||
			out_tmp[0 .. out_ptr] == `<a onclick="return z('j:profile,k:invite','uid=7','test_function','f_uid=7')" href="?z=j:profile,k:invite&uid=7&f_uid=7&f=test_function" class="custom">`);
		
		PNL.funcs.remove("test_function");
	});
	
	UNIT("panel #1", () {
		string t2 = `
		<?interface panel:'test2' public: true ?>
		<?load TestObject ?>
		number is <?= number ?>
		`;
		
		PNL.parse_text(t2);
		assert("test2" in PNL.pnl);
		version(testbytecode) PNL.pnl["test2"].print_bytecode;
		PNL.pnl["test2"].render();
		assert(out_tmp[0 .. out_ptr] == "number is 7");
		
		out_ptr = 0;
		string t = `
		<?interface panel:'panel1' ?>
		<?load TestObject ?>
		<div> some text</div>
		<?panel name: "lala" default: 'test2' ?>
		`;
		
		PNL.parse_text(t);
		assert("panel1" in PNL.pnl);
		version(testbytecode) PNL.pnl["panel1"].print_bytecode;
		PNL.pnl["panel1"].render();
		
		assert(out_tmp[0 .. out_ptr] == `<div> some text</div><div id="lala">number is 7</div>`);
	});
	
	UNIT("panel #2", () {
		string t2 = `
		<?interface panel:'test2' public: true ?>
		<?load TestObject ?>
		number is <?= number ?>
		`;
		
		PNL.parse_text(t2);
		assert("test2" in PNL.pnl);
		version(testbytecode) PNL.pnl["test2"].print_bytecode;
		PNL.pnl["test2"].render();
		assert(out_tmp[0 .. out_ptr] == "number is 7");
		
		out_ptr = 0;
		string t = `
		<?interface panel:'panel2' ?>
		<?load TestObject ?>
		<div> some text</div>
		<?panel name: "lala" default: 'test2' ?>
		`;
		
		PNL.parse_text(t);
		assert("panel2" in PNL.pnl);
		version(testbytecode) PNL.pnl["panel2"].print_bytecode;
		PNL.pnl["panel2"].render();
		
		assert(out_tmp[0 .. out_ptr] == `<div> some text</div><div id="lala">number is 7</div>`);
	});
	
	UNIT("panel #3", () {
		string t1 = `
		<?interface panel:'panel3' public: true ?>
		<?load TestObject ?>
		your mom is awesome!
		`;
		
		PNL.parse_text(t1);
		assert("panel3" in PNL.pnl);
		version(testbytecode) PNL.pnl["panel3"].print_bytecode;
		PNL.pnl["panel3"].render();
		assert(out_tmp[0 .. out_ptr] == "your mom is awesome!");
		
		out_ptr = 0;
		string t2 = `
		<?interface panel:'test2' public: true ?>
		<?load TestObject ?>
		number is <?= number ?>
		`;
		
		PNL.parse_text(t2);
		version(testbytecode) PNL.pnl["test2"].print_bytecode;
		PNL.pnl["test2"].render();
		assert(out_tmp[0 .. out_ptr] == "number is 7");
		
		out_ptr = 0;
		string t = `
		<?interface panel:'test3' ?>
		<?load TestObject ?>
		<div> some text</div>
		<?panel name: "lala" default: 'test2' ?>
		`;
		
		PNL.parse_text(t);
		assert("test3" in PNL.pnl);
		version(testbytecode) PNL.pnl["test3"].print_bytecode;
		PNL.pnl["test3"].render();
		
		assert(out_tmp[0 .. out_ptr] == `<div> some text</div><div id="lala">number is 7</div>`);
	});
	
	UNIT("panel #4", () {
		string t1 = `
		<?interface panel:'panel4' public: true ?>
		<?load TestObject ?>
		your mom is awesome!
		`;
		
		PNL.parse_text(t1);
		assert("panel4" in PNL.pnl);
		version(testbytecode) PNL.pnl["panel4"].print_bytecode;
		PNL.pnl["panel4"].render();
		assert(out_tmp[0 .. out_ptr] == "your mom is awesome!");
		out_ptr = 0;
		
		string t2 = `
		<?interface panel:'test2' public: true ?>
		<?load TestObject ?>
		number is <?= number ?>
		`;
		
		PNL.parse_text(t2);
		assert("test2" in PNL.pnl);
		version(testbytecode) PNL.pnl["test2"].print_bytecode;
		PNL.pnl["test2"].render();
		assert(out_tmp[0 .. out_ptr] == "number is 7");
		out_ptr = 0;
		
		string t = `
		<?interface panel:'test3' public: true ?>
		<?load TestObject ?>
		<div> some text</div>
		<?panel name: "lala" default: 'test2' ?>
		`;
		
		PANELS["lala"] = cast(char[])"panel4";
		
		PNL.parse_text(t);
		assert("test3" in PNL.pnl);
		version(testbytecode) PNL.pnl["test3"].print_bytecode;
		PNL.pnl["test3"].render();
		
		assert(out_tmp[0 .. out_ptr] == `<div> some text</div><div id="lala">your mom is awesome!</div>`);
	});
}

