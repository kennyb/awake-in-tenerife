module unittests;
import tango.stdc.stdio;
import tango.stdc.stdlib;
import tango.stdc.posix.sys.time;

import externs;
import lib;

version(unittests) {
	Unittest[string] test_suites;
	
	//TODO!!!! - add assertEqual
	interface IUnittest {
		void prepare();
		void test();
		void clean();
	}
	
	void UNIT(string name, void delegate() func) {}
	
	abstract class Unittest {
		import panel;
		import shared;
		
		static void add(string name, Unittest o) {
			if(name in test_suites) {
				errorln("DUPLICATE UNIT TEST: ", name);
			} else {
				test_suites[name] = o;
			}
		}
		
		void prepare() {}
		void clean() {}
		void test() {
			errorln("you forgot to extend the Unittest.test() function");
		}
	}
	
	/*
	class TestingUnit : Unittest {
		static this() { Unittest.add(typeof(this).stringof, new typeof(this));}
		
		void prepare() {
		}
		
		void clean() {
		}
		
		void test() {
		}
	}
	*/
	
	class Test_option_parser : Unittest {
		static this() { Unittest.add(typeof(this).stringof, new typeof(this));}
		protected:
		
		void test() {
			option_parser1();
			option_parser2();
			option_parser3();
			option_parser4();
			option_parser5();
			option_parser6();
			option_parser7();
			option_parser8();
			option_parser9();
			option_parser10();
		}
		
		void option_parser1() {
			string t = "{ label: \"options, yeah\", label2: $variable, label3: {label1: \"lala:\", label2: `tex xtt2`}}";
			
			string[string] output;
			output.parse_options(t);
			
			assert("label" in output);
			assert("label2" in output);
			assert("label3" in output);
			assert(output["label"] == "options, yeah");
			assert(output["label2"] == "$variable");
			assert(output["label3"] == "{label1: \"lala:\", label2: `tex xtt2`}");
		}
		
		void option_parser2() {
			string t = "label: \"options, yeah\", label2: $variable, label3: {label1: \"lala:\", label2: `tex xtt2`}";
			
			string[string] output;
			output.parse_options(t);
			
			assert("label" in output);
			assert("label2" in output);
			assert("label3" in output);
			assert(output["label"] == "options, yeah");
			assert(output["label2"] == "$variable");
			assert(output["label3"] == "{label1: \"lala:\", label2: `tex xtt2`}");
		}
		
		void option_parser3() {
			string t = `label: {m: "home"} label2: "setavailability" label3: {date: $date}`;
			
			string[string] output;
			output.parse_options(t);
			
			assert("label" in output);
			assert("label2" in output);
			assert("label3" in output);
			assert(output["label"] == `{m: "home"}`);
			assert(output["label2"] == "setavailability");
			assert(output["label3"] == "{date: $date}");
		}
		
		void option_parser4() {
			string t = "label: 1 label2: 11 label3: '11'";
			
			string[string] output;
			output.parse_options(t);
			
			assert("label" in output);
			assert("label2" in output);
			assert("label3" in output);
			assert(output["label"] == "1");
			assert(output["label2"] == "11");
			assert(output["label3"] == "11");
		}
		
		void option_parser5() {
			string t = "$label: 1 'label2': 11 $label3: '11'";
			
			string[string] output;
			output.parse_options(t);
			
			assert("$label" in output);
			assert("label2" in output);
			assert("$label3" in output);
			assert(output["$label"] == "1");
			assert(output["label2"] == "11");
			assert(output["$label3"] == "11");
		}
		
		void option_parser6() {
			string t = "'label': 1 label2: 11 '$label3': '11'";
			
			string[string] output;
			output.parse_options(t);
			
			assert("label" in output);
			assert("label2" in output);
			assert("$label3" in output);
			assert(output["label"] == "1");
			assert(output["label2"] == "11");
			assert(output["$label3"] == "11");
		}
		
		void option_parser7() {
			string t = "label: 1";
			
			string[string] output;
			output.parse_options(t);
			
			assert("label" in output);
			assert(output["label"] == "1");
		}
		
		void option_parser8() {
			string t = "label";
			
			string[string] output;
			output.parse_options(t);
			
			assert(!("label" in output));
			assert(output == null);
			assert(!output.length);
		}
		
		void option_parser9() {
			string t = "$page_size: 2";
			
			string[string] output;
			output.parse_options(t);
			
			assert("$page_size" in output);
			assert(output["$page_size"] == "2");
		}
		
		void option_parser10() {
			string t = "   {uid: 11} ";
			
			string[string] output;
			output = parse_options(t);
			
			assert("uid" in output);
			assert(output["uid"] == "11");
		}
	}
}

unittest {
	UNIT("clean_text #1", () {
		string t = `
		<td>
			<%set name: "pid" value: $PhotoSeq.pid%>
			<%link panels: {j: photo} args: {pid: $PhotoSeq.next_pid, p: $PhotoSeq.next_page, uid: $zid, m: $Url.m} %>
				<%img {url: $PhotoSeq.url, size: 500, id: "tagme" }%>
			<%endlink%>
			// In the case where you are unable to see the photo, yet it exists, you can:
			//TODO!! - prompt to add as a friend
			//TODO!! - request to see the photo
		</td>
		`;
		
		
		
		string tt = clean_text(t);
		assert(tt == `<td><%set name: "pid" value: $PhotoSeq.pid%><%link panels: {j: photo} args: {pid: $PhotoSeq.next_pid, p: $PhotoSeq.next_page, uid: $zid, m: $Url.m} %><%img {url: $PhotoSeq.url, size: 500, id: "tagme" }%><%endlink%></td>`);
		
		
		t = "lala \"`'''la`lala`\" lala";
		tt = clean_text(t);
		
		assert(tt == "lala \"`'''la`lala`\" lala");
		
		t = "lal'a \"`'''la`lala` l'ala";
		tt = clean_text(t);
		
		assert(tt == "lal'a \"`'''la`lala` l'ala");
	});
	
	UNIT("clean_text #2", () {
		string t = `
		div.innerHTML = '<iframe name="'+this.uniqueId+'" id="'+this.uniqueId+'" src="javascript:void(0)" onload="setTimeout(function(){if_onload(\''+this.uniqueId+'\');},20);"></iframe>';
		
//--------------------------
// additional functions:
//--------------------------
		yeah
		`;
		
		string tt = clean_text(t);
		assert(tt == `div.innerHTML = '<iframe name="'+this.uniqueId+'" id="'+this.uniqueId+'" src="javascript:void(0)" onload="setTimeout(function(){if_onload(\''+this.uniqueId+'\');},20);"></iframe>';yeah`);
	});
	
	UNIT("clean_text #3", () {
		string t = `
		"this is a // "
		yeah
		`;
		
		string tt = clean_text(t);
		assert(tt == `"this is a // "yeah`);
	});
	
	UNIT("clean_text #4", () {
		string t = `
		var	lala = 3;
		`;
		
		string tt = clean_text(t);
		assert(tt == `var lala = 3;`);
	});
	
	UNIT("clean_text #5", () {
		string t = `
		var	lala = 3;	// lala
		`;
		
		string tt = clean_text(t);
		assert(tt == `var lala = 3;`);
	});
}

unittest {
	UNIT("expressions() #1", () {
		bool is_and;
		auto o = expressions("(lala && lala2)", is_and);
		assert(o.length == 2);
		assert(is_and == true);
		assert(o[0] == "lala");
		assert(o[1] == "lala2");
		
		o = expressions("(lala || lala2)", is_and);
		assert(o.length == 2);
		assert(is_and == false);
		assert(o[0] == "lala");
		assert(o[1] == "lala2");
		
		o = expressions("lala && (lala1 || lala2)", is_and);
		assert(o.length == 2);
		assert(is_and == true);
		assert(o[0] == "lala");
		assert(o[1] == "(lala1 || lala2)");
		
		o = expressions("lala && (lala1 || lala2) && lala3", is_and);
		assert(o.length == 3);
		assert(is_and == true);
		assert(o[0] == "lala");
		assert(o[1] == "(lala1 || lala2)");
		assert(o[2] == "lala3");
	});
}

unittest {
	UNIT("toInt()", () {
		assert(toInt("0") == 0);
		assert(toInt("-1") == 0xffffffff);
		assert(toInt("1234") == 1234);
		assert(toInt("2147483647") == int.max);
		assert(toInt("-2147483648") == int.min);
	});
}

unittest {
	UNIT("toUint()", () {
		assert(toUint("0") == 0);
		assert(toUint("-1") != 0xffffffff);
		assert(toUint("1234") == 1234);
		assert(toUint("4294967295") == uint.max);
	});
}

unittest {
	UNIT("toLong()", () {
		assert(toLong("0") == 0);
		assert(toLong("-1") == 0xffffffffffffffff);
		assert(toLong("1234") == 1234);
		assert(toLong("9223372036854775807") == long.max);
		assert(toLong("-9223372036854775808") == long.min);
	});
}

unittest {
	UNIT("toUlong()", () {
		assert(toUlong("0") == 0);
		assert(toUlong("-1") != 0xffffffffffffffff);
		assert(toUlong("1234") == 1234);
		assert(toUlong("18446744073709551615") == ulong.max);
	});
}

unittest {
	UNIT("find_c()", () {
		assert(find_c(`123456789"123456789"123456789`, '1') == 0);
		assert(find_c(`123456789"123456789"123456789`, '4') == 3);
		assert(find_c(`123456789"123456789"123456789`, '9') == 8);
		assert(find_c(`123456789"123456789"123456789`, '1', 1) == 10);
		assert(find_c(`123456789"123456789"123456789`, '4', 4) == 13);
		assert(find_c(`123456789"123456789"123456789`, '9', 9) == 18);
		assert(find_c(`123456789"123456789"123456789`, '1', 11) == 20);
		assert(find_c(`123456789"123456789"123456789`, '4', 14) == 23);
		assert(find_c(`123456789"123456789"123456789`, '9', 19) == 28);
		assert(find_c(`123456789"123456789"123456789`, '9', 29) == -1);
		assert(find_c(`123456789"123456789"123456789`, '1', -1) == -1);
		assert(find_c(`123456789"123456789"123456789`, '1', -10) == -1);
	});
}

unittest {
	UNIT("find_s()", () {
		assert(find_s(`123456789"123456789"123456789`, "123") == 0);
		assert(find_s(`123456789"123456789"123456789`, "456") == 3);
		assert(find_s(`123456789"123456789"123456789`, "789") == 6);
		assert(find_s(`123456789"123456789"123456789`, "9\"1") == 8);
		assert(find_s(`123456789"123456789"123456789`, "123", 1) == 10);
		assert(find_s(`123456789"123456789"123456789`, "456", 4) == 13);
		assert(find_s(`123456789"123456789"123456789`, "789", 9) == 16);
		assert(find_s(`123456789"123456789"123456789`, "123", 11) == 20);
		assert(find_s(`123456789"123456789"123456789`, "456", 14) == 23);
		assert(find_s(`123456789"123456789"123456789`, "789", 19) == 26);
		assert(find_s(`123456789"123456789"123456789`, "789", 29) == -1);
		assert(find_s(`123456789"123456789"123456789`, "789", 27) == -1);
		assert(find_s(`123456789"123456789"123456789`, "123", -1) == -1);
		assert(find_s(`123456789"123456789"123456789`, "123", -10) == -1);
	});
}

unittest {
	UNIT("findr_c()", () {
		assert(findr_c(`123456789"123456789"123456789`, '1') == 20);
		assert(findr_c(`123456789"123456789"123456789`, '4') == 23);
		assert(findr_c(`123456789"123456789"123456789`, '9') == 28);
		assert(findr_c(`123456789"123456789"123456789`, '1', 19) == 10);
		assert(findr_c(`123456789"123456789"123456789`, '4', 19) == 13);
		assert(findr_c(`123456789"123456789"123456789`, '9', 19) == 18);
		assert(findr_c(`123456789"123456789"123456789`, '1', 9) == 0);
		assert(findr_c(`123456789"123456789"123456789`, '4', 9) == 3);
		assert(findr_c(`123456789"123456789"123456789`, '9', 9) == 8);
		assert(findr_c(`123456789"123456789"123456789`, '9', 29) == 28);
		assert(findr_c(`123456789"123456789"123456789`, '1', -1) == -1);
		//assert(findr_c(`123456789"123456789"123456789`, '1', -10) == -1);
	});
}

unittest {
	UNIT("findr_s()", () {
		assert(findr_s(`123456789"123456789"123456789`, "123") == 20);
		assert(findr_s(`123456789"123456789"123456789`, "456") == 23);
		assert(findr_s(`123456789"123456789"123456789`, "789") == 26);
		assert(findr_s(`123456789"123456789"123456789`, "9\"1") == 18);
		assert(findr_s(`123456789"123456789"123456789`, "123", 19) == 10);
		assert(findr_s(`123456789"123456789"123456789`, "456", 19) == 13);
		assert(findr_s(`123456789"123456789"123456789`, "789", 19) == 16);
		assert(findr_s(`123456789"123456789"123456789`, "123", 9) == 0);
		assert(findr_s(`123456789"123456789"123456789`, "456", 9) == 3);
		assert(findr_s(`123456789"123456789"123456789`, "789", 9) == 6);
	});
}

unittest {
	UNIT("replace_cc()", () {
		assert(replace_cc(`123456789"123456789"123456789`, '1', '-') == `-23456789"-23456789"-23456789`);
		assert(replace_cc(`123456789"123456789"123456789`, '9', '-') == `12345678-"12345678-"12345678-`);
	});
}

unittest {
	UNIT("replace_cs()", () {
		assert(replace_cs(`123456789"123456789"123456789`, '1', "ññ") == `ññ23456789"ññ23456789"ññ23456789`);
		assert(replace_cs(`123456789"123456789"123456789`, '9', "ññ") == `12345678ññ"12345678ññ"12345678ññ`);
	});
}

unittest {
	UNIT("replace_ss()", () {
		assert(replace_ss("günther is awesome", "günther", "your mom") == "your mom is awesome");
		assert(replace_ss("günther is awesome", "awesome", "your mom") == "günther is your mom");
	});
}

unittest {
	UNIT("replace_sc()", () {
		assert(replace_sc("lala", "lala", 'c') == "c");
		assert(replace_sc("lalalala", "lala", 'c') == "cc");
		assert(replace_sc("12lala34", "lala", 'c') == "12c34");
		assert(replace_sc("lal;", ";}", '}') == "lal;");
		assert(replace_sc(";}alal;;", ";}", '}') == "}alal;;");
	});
}

unittest {
	UNIT("remove_s()", () {
		assert(remove_s("123412341234", "12") == "343434");
		assert(remove_s("123412341234", "34") == "121212");
	});
}

unittest {
	UNIT("trim()", () {
		assert(trim(" ") == "");
		assert(trim(" lala ") == "lala");
		assert(trim("\rlala\n") == "lala");
		assert(trim("\0 \n lala\n \r ") == "lala");
		string lala = "lala%";
		assert(trim(lala[0 .. 4]) == "lala");
		assert(trim(lala[3 .. 4]) == "a");
		assert(trim(lala[4 .. 4]) == "");
	});
}

unittest {
	UNIT("strip_serach()", () {
		assert(strip_search("Chillin' and stuff") == "%chillin%and%stuff%");
		assert(strip_search("gay áccénts and ñññ") == "%gay%cc%nts%and%");
	});
}

unittest {
	UNIT("find_noquote(string, char)", () {
		assert(find_noquote(`123456789"123456789"123456789`, '1') == 0);
		assert(find_noquote(`123456789"123456789"123456789`, '4') == 3);
		assert(find_noquote(`123456789"123456789"123456789`, '9') == 8);
		assert(find_noquote(`123456789"123456789"123456789`, '1', 1) == 20);
		assert(find_noquote(`123456789"123456789"123456789`, '4', 4) == 23);
		assert(find_noquote(`123456789"123456789"123456789`, '9', 9) == 28);
		
		assert(find_noquote(`123456789"123456789'123456789`, '1', 1) == -1);
		assert(find_noquote(`123456789"123456789'123456789`, '4', 4) == -1);
		assert(find_noquote(`123456789"123456789'123456789`, '9', 9) == -1);
		
		assert(find_noquote(`12345678\"12345678\"123456789`, '1') == 0);
		assert(find_noquote(`12345678\"12345678\"123456789`, '4') == 3);
		assert(find_noquote(`12345678\"12345678\"123456789`, '\\') == 8);
		assert(find_noquote(`12345678\"12345678\"123456789`, '1', 1) == 10);
		assert(find_noquote(`12345678\"12345678\"123456789`, '4', 4) == 13);
		assert(find_noquote(`12345678\"12345678\"123456789`, '7', 9) == 16);
	});
}

unittest {
	UNIT("find_noquote(string, string)", () {
		assert(find_noquote(`123456789"123456789"123456789`, `123`) == 0);
		assert(find_noquote(`123456789"123456789"123456789`, `456`) == 3);
		assert(find_noquote(`123456789"123456789"123456789`, `789`) == 6);
		assert(find_noquote(`123456789"123456789"123456789`, `9"1`) == 8);
		assert(find_noquote(`123456789"123456789"123456789`, `123`, 1) == 20);
		assert(find_noquote(`123456789"123456789"123456789`, `456`, 4) == 23);
		assert(find_noquote(`123456789"123456789"123456789`, `789`, 9) == 26);
		
		assert(find_noquote(`12345678\"12345678\"123456789`, `123`) == 0);
		assert(find_noquote(`12345678\"12345678\"123456789`, `456`) == 3);
		assert(find_noquote(`12345678\"12345678\"123456789`, "78\\") == 6);
		assert(find_noquote(`12345678\"12345678\"123456789`, `\"1`) == 8);
		assert(find_noquote(`12345678\"12345678\"123456789`, `123`, 1) == 10);
		assert(find_noquote(`12345678\"12345678\"123456789`, `456`, 4) == 13);
		assert(find_noquote(`12345678\"12345678\"123456789`, "78\\", 9) == 16);
	});
}

unittest {
	UNIT("cleanse_url_string()", () {
		assert(cleanse_url_string("lala=hello+I'm%20kenny") == "lala=hello I'm kenny");
		assert(cleanse_url_string( "%0A%0D%0A%0A") == "\n\n\n");
	});
}

unittest {
	UNIT("enc_int() #1", () {
		assert(enc_int(0) == "0");
		assert(enc_int(11) == "n");
		assert(enc_int(15) == "f");
		assert(enc_int(63) == "-");
		assert(enc_int(64) == "0y");
	});
	
	UNIT("enc_int() #2", () {
		for(uint i = 0; i < 100; i++) {
			auto input = rand();
			string tmp = enc_int(input);
			if(tmp.length > 2) {
				tmp.length = 2;
			}
			
			uint sid5 = dec_int(tmp);
			
			assert(enc_int(sid5, 2) == tmp);
		}
	});
}

unittest {
	UNIT("dec_int()", () {
		assert(dec_int(enc_int(64)) == 64);
		assert(dec_int(enc_int(123456)) == 123456);
		assert(dec_int(enc_int(45654353)) == 45654353);
		assert(dec_int(enc_int(4565987340934507664)) == 4565987340934507664);
	});
}





/+
unittest {
	
	/*
	UNIT("version #1", () {
		string t = `
		<?load TestObject ?>
		<?version lala 1 ?>
			lala version 1
		<?endversion?>
		<?version lala 2 ?>
			lala version 2
		<?endversion?>
		`;
		
		PNL.parse_text("test1", t);
		PNL.pnl["test1"].render();
		
		stdoutln("out: '^'", out_tmp[0 .. out_ptr]);
		//assert(out_tmp[0 .. out_ptr] == "lala version 1");
		
		
	}); */
	
	
	debug noticeln("-- Finished unit testing --");
}
+/

