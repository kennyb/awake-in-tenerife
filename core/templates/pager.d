module templates.pager;
import core;
import panel;
import lib;
import templates.link;
import shared;

class TemplatePager : TemplateInterface {
	import Integer = tango.text.convert.Integer;
	
	static typeof(this)[] instances;
	static this() {
		PNL.registerTemplate("pager", &this.create);
	}
	
	static private void create(inout PNL pnl, string cmd, string inside) {
		instances ~= new typeof(this)(pnl, inside);
		PNLByte* p = pnl.newByte();
		p.action = pnl_action_template;
		p.dg = &instances[$ - 1].render;
	}
	
	private int page;
	private int last_page;
	private int* ptr_page;
	private int* ptr_last_page;
	private TemplateLink link;
	
	this(inout PNL pnl, string params) {
		string[string] opts;
		string page_var;
		string* val;
		
		opts.parse_options(params);
		
		val = "page_var" in opts;
		if(val) {
			page_var = *val;
		} else {
			page_var = "page";
		}
		
		string s_page;
		string s_last_page;
		uint page;
		uint last_page;
		val = "page" in opts;
		if(val) {
			s_page = *val;
		} else {
			s_page = "1";
		}
		
		val = "last_page" in opts;
		if(val) {
			s_last_page = *val;
		} else {
			pnl.inlineError("You must define last_page for template 'pager'");
			s_last_page = "1";
		}
		
		if(s_page[0] >= '0' && s_page[0] <= '9') {
			page = toUint(s_page);
		} else if(s_page[0] == '$') {
			string var = s_page[1 .. $];
			int v_scope = pnl.find_var(var);
			if(v_scope >= 0) {
				if(pnl.var_type[v_scope][var] == pnl_action_var_uint) {
					ptr_page = cast(int*)pnl.var_ptr[v_scope][var];
				}
			} else {
				debug errorln("variable '", var, "' is not registered");
			}
		}
		
		if(s_last_page[0] >= '0' && s_page[0] <= '9') {
			last_page = toUint(s_last_page);
		} else if(s_last_page[0] == '$') {
			string var = s_last_page[1 .. $];
			int v_scope = pnl.find_var(var);
			if(v_scope >= 0) {
				if(pnl.var_type[v_scope][var] == pnl_action_var_uint) {
					ptr_last_page = cast(int*)pnl.var_ptr[v_scope][var];
				}
			} else {
				debug errorln("variable '", var, "' is not registered");
			}
		}
		
		auto args_loc = find(params, "args:");
		if(args_loc != -1) {
			size_t i = args_loc;
			while(i < params.length && params[i++] != '{') { 
			}
			
			params = params[0 .. i] ~ page_var ~ `: "!!page!!", ` ~ params[i .. $];
		} else {
			params ~= " args: {" ~ page_var ~ `: "!!page!!"}`;
		}
		
		link = new TemplateLink(pnl, params);
	}
	
	void render() {
		if(ptr_last_page) {
			last_page = *ptr_last_page;
		}
		
		if(last_page > 0) {
			if(ptr_page) {
				page = *ptr_page;
			}
		
			size_t cur_ptr = out_ptr;
			link.render();
			string link = out_tmp[cur_ptr .. out_ptr].dup;
			out_ptr = cur_ptr;
			auto loc1 = find(link, "!!page!!");
			auto loc2 = loc1+8;
			auto loc3 = find(link[loc2 .. $], "!!page!!")+loc2;
			auto loc4 = loc3+8;
			auto len = link.length;
			
			void prt_link(int page) {
				prt(link[0 .. loc1]);
				prt(Integer.toString(page));
				prt(link[loc2 .. loc3]);
				prt(Integer.toString(page));
				prt(link[loc4 .. len]);
			}
			
			if(page > 0) {
				prt_link(page-1);
				prt("&lt;</a>&nbsp;");
			} else {
				prt("&lt;&nbsp;");
			}
				
			if(page != 0) {
				prt_link(0);
				prt("1</a>&nbsp;");
			}
	
			
			if(last_page == 4 && page == 4) {
				prt_link(1);
				prt("2</a>&nbsp;");
			} else if(page > 3) {
				prt("...&nbsp;");
			}
	
			if(last_page > page-2 && page > 2) {
				prt_link(page-2);
				prt(Integer.toString(page-1));
				prt("</a>&nbsp;");
			}
	
			if(last_page > page-1 && page > 1) {
				prt_link(page-1);
				prt(Integer.toString(page));
				prt("</a>&nbsp;");
			}
	
			prt(Integer.toString(page+1));
			prt("&nbsp;");
	
			if(last_page > page+1) {
				prt_link(page+1);
				prt(Integer.toString(page+2));
				prt("</a>&nbsp;");
			}
	
			if(last_page > page+2) {
				prt_link(page+2);
				prt(Integer.toString(page+3));
				prt("</a>&nbsp;");
			}
	
			if(last_page == 4 && page == 0) {
				prt_link(3);
				prt("4</a>&nbsp;");
			} else if(page < last_page-3) {
				prt("...&nbsp;");
			}
			
			if(last_page > 0 && last_page != page) {
				prt_link(last_page);
				prt(Integer.toString(last_page+1));
				prt("</a>&nbsp;");
			}
	
			if(last_page > page) {
				prt_link(page+1);
				prt("&gt;</a>&nbsp;");
			} else {
				prt("&gt;&nbsp;");
			}
		}
	}
}
