module objects;

import panel;
import lib;
import shared;


/*

I can automate this by adding an array with all of the object names, then simply changing the hashing of the objects...

a static object will just be "Object"
a normal object would be "Object_[panel name]_[scope]_[instance #]

This will be slightly more efficient as well.
The static method of the object can add a reference to itself in the array, and the type of object that it is

*/

extern void delegate() new_object(inout PNL pnl, string cmd, string name, inout string[string] params = null) {
	//errorln("*** Loading Object: ", pnl.name, " :: ", name);
	int instance = ((pnl.name in instance_count) && (name in instance_count[pnl.name])) ? ++instance_count[pnl.name][name] : 0;
	
	version(unittests) {
		switch(name) {
			// test objects
			case "Url":
				normal_objects[pnl.name][name][instance] = available_objects["Url"](pnl, cmd, params);
				normal_objects[pnl.name][name][instance].register(pnl, cmd, params);
				return &normal_objects[pnl.name][name][instance].load;
				
			case "TestObject":
				normal_objects[pnl.name][name][instance] = new TestObject;
				normal_objects[pnl.name][name][instance].register(pnl, cmd, params);
				return &normal_objects[pnl.name][name][instance].load;
				
			case "TestStaticObject":
				static_objects[name] = new TestStaticObject;
				instance_count[pnl.name][name] = instance;
				static_objects[name].register(pnl, cmd, params);
				static_object_loaded[name][pnl.name] = true;
				return &static_objects[name].load;
			
			default:
		}
	}
	
	//errorln("*** New Object: ", pnl.name, " :: ", name, " ", instance);
	TemplateObject function(inout PNL pnl, string cmd, inout string[string] params)* ptr_obj = name in available_objects;
	
	if(ptr_obj) {
		instance_count[pnl.name][name] = instance;
		
		TemplateObject function(inout PNL pnl, string cmd, inout string[string] params) obj_init = *ptr_obj;
		TemplateObject obj = obj_init(pnl, cmd, params);
		normal_objects[pnl.name][name][instance] = obj;
		if(obj) {
			return &obj.load;
		}
	}
	
	
	pnl.inlineError("Could not find module '"~name~"'");
	return null;
}

static this() {
	// standard objects (that come with every installation)
	PNL.registerObj("Stats", &R_Stats.create);
	PNL.registerObj("Url", &Url.create);
	//TODO!! - fix Array
	//PNL.registerObj("Array", &Array.factory);
}

class Url : TemplateObject {
	static const string name = "Url";
	
	//OPTIMIZE!!! - merge int/uint long/ulong into one array
	
	private string[] keys;
	private uint[] isset;
	private uint[] types;
	private uint[] offsets;
	
	private long[] ints;
	private ulong[] uints;
	private string*[] strings;
	
	protected TemplateObject create(inout PNL pnl, string cmd, inout string[string] params) {
		noticeln("CREATE");
		auto obj = new typeof(this)();
		obj.register(pnl, params);
		return obj;
	}
	
	private void register(inout PNL pnl, inout string[string] params) {
		noticeln("REGISTER");
		string parent = "";
		string* ptr_parent = "parent" in params;
		if(ptr_parent) {
			parent = *ptr_parent ~ '.';
			params.remove("parent");
		}
		
		foreach(string key, string value; params) {
			if(value == "string") {
				strings ~= pnl.getGlobalString();
				offsets ~= strings.length-1;
				isset ~= 0;
				keys ~= *pnl.getConst(key);
				types ~= pnl_action_var_str;
				
				pnl.registerUint(parent ~ name ~ '.' ~ key ~ ".isset", &isset[$-1]);
				pnl.registerString(parent ~ name ~ '.' ~ key, strings[$-1]);
			} else if(value == "uint" || value == "ulong") {
				uints ~= 0;
				offsets ~= uints.length-1;
				isset ~= 0;
				keys ~= *pnl.getConst(key);
				types ~= pnl_action_var_uint;
				
				pnl.registerUint(parent ~ name ~ '.' ~ key ~ ".isset", &isset[$-1]);
				if(value == "uint") {
					pnl.registerUint(parent ~ name ~ '.' ~ key, cast(uint*) &uints[$-1]);
				} else {
					pnl.registerUlong(parent ~ name ~ '.' ~ key, &uints[$-1]);
				}
			} else if(value == "int" || value == "long") {
				ints ~= 0;
				offsets ~= ints.length-1;
				isset ~= 0;
				keys ~= *pnl.getConst(key);
				types ~= pnl_action_var_int;
				
				pnl.registerUint(parent ~ name ~ '.' ~ key ~ ".isset", &isset[$-1]);
				if(value == "int") {
					pnl.registerInt(parent ~ name ~ '.' ~ key, cast(int*) &ints[$-1]);
				} else {
					pnl.registerLong(parent ~ name ~ '.' ~ key, &ints[$-1]);
				}
			} else {
				pnl.inlineError("I do not know what type '" ~ value ~ "' is for " ~ key);
			}
		}
	}
	
	protected void load() {
		noticeln("LOAD ", strings.length, " ", ints.length, " ", uints.length);
		
		foreach(i, key; keys) {
			auto ptr_val = key in POST;
			auto type = types[i];
			auto offset = offsets[i];
			noticeln("******* string ", key, " = ", ptr_val ? *ptr_val : "unset");
			
			isset[i] = ptr_val ? 1 : 0;
			
			if(type == pnl_action_var_str) {
				*strings[offset] = ptr_val ? *ptr_val : null;
			} else if(type == pnl_action_var_int) {
				ints[offset] = ptr_val ? toLong(*ptr_val) : 0;
			} else if(type == pnl_action_var_uint) {
				uints[offset] = ptr_val ? toUlong(*ptr_val) : 0;
			}
		}
	}
	
	protected void unload() {
		
	}
}

version(unittests) {
	class Test_TemplateObject_Url : Unittest {
		static this() { Unittest.add(typeof(this).stringof, new typeof(this));}
		
		void prepare() {
			reset_state();
		}
		
		void clean() {
			reset_state();
		}
		
		void test() {
			url1();
			
			reset_state();
			
			url2();
		}
		
		void url1() {
			PNL.parse_text(`
				<?interface panel:'url1' ?>
				<%load Url { h: string } %>
				<%=Url.h%>
				<%if $Url.h == "lalala" %>
					false
				<%endif%>
				<%if $Url.h == "lalalalala" %>
					true
				<%endif%>
			`);
			
			POST["h"] = "lalalalala";
			assert("url1" in PNL.pnl);
			PNL.pnl["url1"].render();
			assert(out_tmp[0 .. out_ptr] == `lalalalalatrue`);
		}
		
		void url2() {
			PNL.parse_text(`
				<?interface panel:'url2' ?>
				<%load Url { h: int } %>
				<%=Url.h%>
				<%if $Url.h == 12345 %>
					false
				<%endif%>
				<%if $Url.h == 1234 %>
					true
				<%endif%>
			`);
			
			POST["h"] = "1234";
			assert("url2" in PNL.pnl);
			PNL.pnl["url2"].render();
			assert(out_tmp[0 .. out_ptr] == `1234true`);
		}
	}
}

/+
class Array : TemplateObject {
	static const string name = "Array";
	
	static TemplateObject factory(inout PNL pnl, string cmd, inout string[string] params) {
		// factory method to produce these objects ;)
		typeof(this) obj = new typeof(this)();
		obj.register(pnl, params);
		return cast(TemplateObject)obj;
	}
	
	string separator = ",";
	uint type = pnl_action_var_int;
	string* ptr_input;
	
	uint current;
	uint column;
	uint total;
	uint count;
	
	int* ptr_id;
	uint* ptr_page;
	uint* ptr_page_size;
	uint* ptr_width;
	
	int int_value;
	uint[] int_values;
	
	string str_value;
	string[] str_values;
	
	//ulong long_value;
	//ulong[] long_values;
	
	uint width = 4;
	uint page = 0;
	uint page_size = 1000000;
	
	void register(inout PNL pnl, inout string[string] params) {
		string* ptr_value;
		string value;
		
		ptr_value = "input" in params;
		if(ptr_value) {
			value = *ptr_value;
			if(value.length && value[0] == '$') {
				//errorln("TODO!! - arrays with variables are not yet implemented");
				value = value[1 .. $];
				int v_scope = pnl.find_var(value);
				if(v_scope >= 0) {
					auto var_type = pnl.var_type[v_scope][value];
					if(var_type == pnl_action_var_str || type == pnl_action_var_uint) {
						ptr_input = pnl.var_str[v_scope][value];
					}
				}
			} else {
				ptr_input = ptr_value;
			}
		} else {
			("serious problem dude: you didn't provide an input to your array");
		}
		
		ptr_value = "type" in params;
		if(ptr_value) {
			value = *ptr_value;
			switch(value) {
			case "int":
				type = pnl_action_var_int;
				break;
			//case "uint":
			//	type = pnl_action_var_uint;
			//	break;
			//case "long":
			//	type = pnl_action_var_long;
			//	break;
			//case "ulong":
			//	type = pnl_action_var_ulong;
			//	break;
			case "string":
				type = pnl_action_var_str;
				break;
				
			default:
				errorln("array type is not known - try int/string");
			}
		}
		
		ptr_value = "name" in params;
		if(ptr_value) {
			value = *ptr_value;
			// register the loop function below
			pnl.registerLoop(value.dup, &loop);
			pnl.registerUint(value ~ ".current", &current);
			pnl.registerUint(value ~ ".column", &column);
			pnl.registerUint(value ~ ".total", &total);
			pnl.registerUint(value ~ ".count", &count);
			
			switch(type) {
			case pnl_action_var_int:
				pnl.registerInt(value ~ ".value", &int_value);
				break;
				
			case pnl_action_var_str:
				pnl.registerString(value ~ ".value", &str_value);
				break;
			}
		}
	}
	
	void load() {
		//if(ptr_id && *ptr_id != this.id) {
		//	this.id = *ptr_id;
		//}
		
		if(ptr_page_size) {
			this.page_size = *ptr_page_size;
		}
		
		if(ptr_page) {
			this.page = *ptr_page;
		}
		
		if(ptr_width) {
			this.width = *ptr_width;
		}
		
		//ids = list(this.id, page, page_size, total);
		string input = *ptr_input;
		size_t separator_len = separator.length;
		size_t last = 0;
		switch(type) {
		case pnl_action_var_int:
			for(size_t i = 0; i < input.length; i++) {
				if(input[i .. i+separator_len] == separator) {
					int_values ~= toInt(input[last .. i]);
					last = i + separator_len;
					i += separator_len;
				}
			}
			
			int_values ~= toInt(input[last .. $]);
			count = cast(uint)int_values.length;
			break;
			
		case pnl_action_var_str:
			for(size_t i = 0; i < input.length; i++) {
				if(input[i .. i+separator_len] == separator) {
					str_values ~= input[last .. i];
					last = i + separator_len;
					i += separator_len;
				}
			}
			
			str_values ~= input[last .. $];
			count = cast(uint)str_values.length;
			break;
		}
		
		column = -1;
		current = -1;
	}
	
	int loop() {
		if(++current < count) {
			if(++column >= width) {
				column = 0;
			}
		
			switch(type) {
			case pnl_action_var_int:
				int_value = int_values[current];
				break;
				
			case pnl_action_var_str:
				str_value = str_values[current];
				break;
			}
			
			return true;
		} else {
			return false;
		}
	}
}

version(unittests) {
	class Test_TemplateObject_Array : Unittest {
		static this() { Unittest.add(typeof(this).stringof, new typeof(this));}
		
		void prepare() {
			reset_state();
		}
		
		void clean() {
			reset_state();
		}
		
		void test() {
			array1();
			
			reset_state();
			
			array2();
			
			reset_state();
			
			array3();
			
			reset_state();
		}
		
		void array1() {
			PNL.parse_text(`
				<?interface panel:'array1' ?>
				<%load Array {input: "1234,1111,0,1,2,3", type: "int", name: "Array.h" } %>
				<%loop Array.h %>
					<%=Array.h.current%>:<%=Array.h.value%>< >
				<%endloop%>
			`);
			
			assert("array1" in PNL.pnl);
			PNL.pnl["array1"].render();
			assert(out_tmp[0 .. out_ptr] == `0:1234 1:1111 2:0 3:1 4:2 5:3 `);
		}
		
		void array2() {
			PNL.parse_text(`
				<?interface panel:'array2' ?>
				<%load Array {input: "1234,1111,0,1,lalala", type: "string", name: "Array.h" } %>
				<%loop Array.h %>
					<%=Array.h.current%>:<%=Array.h.value%>< >
				<%endloop%>
			`);
			
			assert("array2" in PNL.pnl);
			PNL.pnl["array2"].render();
			assert(out_tmp[0 .. out_ptr] == `0:1234 1:1111 2:0 3:1 4:lalala `);
		}
		
		void array3() {
			PNL.parse_text(`
				<?interface panel:'array3' ?>
				<%load Url { h: string } %>
				<%load Array {input: $Url.h, type: "int", name: "Array.Url.h" } %>
				<%loop Array.Url.h %>
					<%=Array.Url.h.current%>:<%=Array.Url.h.value%>< >
				<%endloop%>
			`);
			
			POST["h"] = "1234,1111,0,1,2,3";
			assert("array3" in PNL.pnl);
			PNL.pnl["array3"].render();
			assert(out_tmp[0 .. out_ptr] == `0:1234 1:1111 2:0 3:1 4:2 5:3 `);
		}
	}
}
+/


class R_Stats : TemplateObject {
	static const string name = "Stats";
	static R_Stats stats;
	static this() {
		stats = new typeof(this);
	}
	
	protected TemplateObject create(inout PNL pnl, string cmd, inout string[string] params) {
		//pnl.registerInt(name ~ ".request_queries", &request_queries);
		/*
		pnl.registerString(name ~ ".firstname", &firstname);
		pnl.registerString(name ~ ".lastname", &lastname);
		pnl.registerString(name ~ ".photo", &photo);
		pnl.registerFunction(name ~ ".is_friend", &is_friend);
		pnl.registerFunction(name ~ ".invited_me", &invited_me);
		pnl.registerFunction(name ~ ".invited_her", &invited_her);
		*/
		
		return cast(TemplateObject)stats;
	}
	
	int request_queries;
	
	int num_queries;
	int total_query_time;
	int avg_query_time;
	int uptime;
	int index_requests;
	int panel_requests;
	int page_requests;
	
	
	protected void load() {
		
	}
	
	protected void unload() {
		
	}
}

version(unittests) {
	class TestStaticObject : TemplateObject {
		import tango.stdc.stdlib : rand;
		 
		const string name = "TestStaticObject";
		uint url_uid;
		int random = 22;
		
		void register(inout PNL pnl, inout string[string] params) {
			pnl.registerUint("url_uid", &url_uid);
			pnl.registerInt("random", &random);
		}
		
		void load() {
			random = rand();
			string* p_uid = "uid" in POST;
			if(p_uid) {
				url_uid = toUint(*p_uid);
			} else {
				url_uid = 33;
			}
		}
	}
	
	class TestObject : TemplateObject {
		static uint inst = 0;
		const string name = "TestObject";
		
		//variables go here
		uint number;
		uint number2;
		int* ptr_number3;
		int number3;
		uint current;
		uint next;
		uint column;
		uint total;
		uint count;
		uint width = 4;
		uint my_inst;
		
		string loop_text;
		string loop_column_text;
		string text, text_utf8, empty_text;
		string[] numbers;
		
		void register(inout PNL pnl, inout string[string] params) {
			my_inst = inst++;
			pnl.registerUint("number", &number);
			pnl.registerUint("number2", &number2);
			pnl.registerInt("number3", &number3);
			number = 5;
			number2 = 7;
			number3 = -3;
			
			pnl.registerUint("loop_next", &next);
			pnl.registerUint("loop_current", &current);
			pnl.registerUint("loop_column", &column);
			pnl.registerUint("loop_total", &total);
			pnl.registerLoop("testloop", &testloop);
			
			text = "test text";
			text_utf8 = "$³²¹";
			empty_text = "";
			numbers = null;
			numbers ~= "zero";
			numbers ~= "one";
			numbers ~= "two";
			numbers ~= "three";
			numbers ~= "four";
			numbers ~= "five";
			numbers ~= "six";
			numbers ~= "seven";
			numbers ~= "eight";
			pnl.registerString("string", &text);
			pnl.registerString("string_utf8", &text_utf8);
			pnl.registerString("empty_string", &empty_text);
			pnl.registerString("loop_text", &loop_text);
			pnl.registerString("loop_column_text", &loop_column_text);
			pnl.registerFunction("testfunc_true", &testfunc_true);
			pnl.registerFunction("testfunc_false", &testfunc_false);
			pnl.registerFunction("testfunc_toInt", &testfunc_toInt);
			
			foreach(string key, string value; params) {
				if(value[0] == '$') {
					string var = value[1 .. $];
					int v_scope = pnl.find_var(var);
					if(v_scope >= 0) {
						if(key == "number3" && pnl.var_type[v_scope][var] == pnl_action_var_uint) {
							ptr_number3 = cast(int*)pnl.var_ptr[v_scope][var];
						}
					} else {
						debug errorln("variable '", var, "' is not registered");
					}
				} else if(value[0] >= '0' && value[0] <= '9') {
					if(key == "number2") {
						number2 = toUint(value);
					}
				}
			}
		}
		
		void load() {
			number = 7;
			total = 12;
			count = 8;
			column = 0;
			
			current = 0;
			next = 0;
			
			if(ptr_number3) {
				number3 = *ptr_number3;
			}
		}
		
		// increment the loop functions go here....
		int testloop() {
			current = column = next++;
			
			if(column == width) {
				column = 0;
			}
			
			loop_text = numbers[current];
			loop_column_text = numbers[column];
			
			return (current < count);
		}
		
		static long testfunc_true(string args) {
			return 1;
		}
		
		static long testfunc_false(string args) {
			return 0;
		}
		
		static long testfunc_toInt(string args) {
			return toInt(args);
		}
	}
	
	class Test_TemplateObject_TestObject : Unittest {
		static this() { Unittest.add(typeof(this).stringof, new typeof(this));}
		
		void prepare() {
			reset_state();
		}
		
		void clean() {
			reset_state();
		}
		
		void test() {
			obj1();
			reset_state();
			
			obj2();
			reset_state();
			
			obj3();
			reset_state();
			
			obj4();
			reset_state();
			
			obj5();
			reset_state();
			
			obj6();
			reset_state();
			
			obj7();
			reset_state();
			
			obj8();
			reset_state();
			
			obj9();
			reset_state();
			
			obj10();
			reset_state();
			
			obj11();
			reset_state();
		}
		
		void obj1() {
			PNL.parse_text(`
				<?interface panel:'object1' ?>
				<?load TestObject { number2: 11 } ?>
				number2 is <?= number2 ?>
			`);
			
			assert("object1" in PNL.pnl);
			PNL.pnl["object1"].render();
			assert(out_tmp[0 .. out_ptr] == "number2 is 11");
		}
		
		void obj2() {
			PNL.parse_text(`
				<?interface panel:'object2' ?>
				<?load TestObject { number2: 11 } ?>
				<?if number2 == 11 ?>
					good
				<?endif?>
			`);
			
			assert("object2" in PNL.pnl);
			PNL.pnl["object2"].render();
			assert(out_tmp[0 .. out_ptr] == "good");
		}
		
		void obj3() {
			PNL.parse_text(`
				<?interface panel:'object3' ?>
				<?load TestObject { number2: 11 } ?>
				<?if number2 == 11 ?>
					<?load TestObject {number2: 13}?>
					number2 is <?=number2?>
				<?endif?>
			`);
			
			assert("object3" in PNL.pnl);
			PNL.pnl["object3"].render();
			assert(out_tmp[0 .. out_ptr] == "number2 is 13");
		}
		
		void obj4() {
			PNL.parse_text(`
				<?interface panel:'object4' ?>
				<?load TestObject { number2: 11 } ?>
				<?if number2 == 11 ?>
					<?load TestObject {number2: 13}?>
					number2 is <?=number2?>
				<?endif?>
				number2 is <?=number2?>
			`);
			
			assert("object4" in PNL.pnl);
			PNL.pnl["object4"].render();
			assert(out_tmp[0 .. out_ptr] == "number2 is 13number2 is 13");
		}
		
		void obj5() {
			PNL.parse_text(`
				<?interface panel:'object5' ?>
				<?load TestObject { number2: 11, number3: $number2 } ?>
				<?if number2 == 11 ?>
					number3 is <?=number3?>
				<?endif?>
			`);
			
			assert("object5" in PNL.pnl);
			PNL.pnl["object5"].render();
			assert(out_tmp[0 .. out_ptr] == "number3 is 11");
		}
		
		void obj6() {
			PNL.parse_text(`
				<?interface panel:'object6' ?>
				<?load TestObject { number2: 11, number3: $number2 } ?>
				<?if number2 == 11 && number3 == 11 ?>
					<?load TestObject {number2: 13, number3: $number2}?>
					number3 is <?=number3?>
				<?endif?>
				number3 is <?=number3?>
			`);
			
			assert("object6" in PNL.pnl);
			PNL.pnl["object6"].render();
			assert(out_tmp[0 .. out_ptr] == "number3 is 13number3 is 13");
		}
		
		void obj7() {
			PNL.parse_text(`
				<?interface panel:'object7' ?>
				<?load TestStaticObject ?>
				url_uid is <?=url_uid?>
			`);
			
			POST["uid"] = "22";
			assert("object7" in PNL.pnl);
			PNL.pnl["object7"].render();
			assert(out_tmp[0 .. out_ptr] == "url_uid is 22");
		}
		
		void obj8() {
			PNL.parse_text(`
				<?interface panel:'object8' ?>
				<?load TestStaticObject ?>
				random is <?=random?>
			`);
			
			assert("object8" in PNL.pnl);
			PNL.pnl["object8"].render();
			assert(out_tmp[0 .. out_ptr] != "random is 22");
			string lala = out_tmp[0 .. out_ptr].dup;
			out_ptr = 0;
			
			PNL.parse_text(`
				<?interface panel:'test2' ?>
				<?load TestStaticObject ?>
				random is <?=random?>
			`);
			
			assert("test2" in PNL.pnl);
			PNL.pnl["test2"].render();
			assert(out_tmp[0 .. out_ptr] == lala);
			out_ptr = 0;
			
			PNL.parse_text(`
				<?interface panel:'test3' ?>
				<?load TestStaticObject ?>
				random is <?=random?>
				<?if random != 22 ?>
					<?load TestStaticObject ?>
					random is <?=random?>
				<?endif?>
			`);
			
			assert("test3" in PNL.pnl);
			PNL.pnl["test3"].render();
			assert(out_tmp[0 .. out_ptr] == lala ~ lala);
		}
		
		void obj9() {
			PNL.parse_text(`
				<?interface panel:'object9' ?>
				<?load TestObject { number2: 11 } ?>
				<?=number2?>
				<?if number2 == 11 ?>
					good
				<?endif?>
				<?load TestObject { number2: 13 } ?>
				<?=number2?>
				<?if number2 == 13 ?>
					good
				<?endif?>
			`);
			
			assert("object9" in PNL.pnl);
			PNL.pnl["object9"].render();
			assert(out_tmp[0 .. out_ptr] == "11good13good");
		}
		
		void obj10() {
			PNL.parse_text(`
				<?interface panel:'object10' ?>
				<?load TestObject ?>
				<?=testfunc_true?>-
				<?if testfunc_true ?>
					good
				<?endif?>
				<?load TestObject ?>
				<?=testfunc_false?>
				<?if testfunc_false ?>
					bad
				<?endif?>
			`);
			
			assert("object10" in PNL.pnl);
			PNL.pnl["object10"].render();
			assert(out_tmp[0 .. out_ptr] == "1-good0");
		}
		
		void obj11() {
			PNL.parse_text(`
				<?interface panel:'object10' ?>
				<?load TestObject ?>
				<?if testfunc_true ?>
					<%=testfunc_toInt 3%>
				<?endif?>
				<?load TestObject ?>
				-<%=testfunc_toInt 5%>
			`);
			
			assert("object10" in PNL.pnl);
			PNL.pnl["object10"].render();
			assert(out_tmp[0 .. out_ptr] == "3-5");
		}
	}
}
