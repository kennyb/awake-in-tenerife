module lib;

static if(!is(string == char[])) {
	alias char[] string;
}

import tango.stdc.stdio;
import tango.stdc.stdlib;
import tango.stdc.posix.sys.time;
import Integer = tango.text.convert.Integer;
import Float = tango.text.convert.Float;
import tango.core.Vararg;
//import Process = tango.sys.Process;
import tango.io.FilePath;

//import shared;
import libowfat;
import externs;
//version(unittests) import unittests;

extern(C) char* strptime(in char*, in char*, tm*);

// success is 0-infinity
// failure is -1 - -1000
enum {
	SUCCESS = 0,
	FAILURE = -1,
	HACKING = -1000,
}

string toString(...) {
	string str;
	for(size_t i = 0; i < _arguments.length; i++) {
		if(_arguments[i] == typeid(int)) {
			str ~= Integer.toString(va_arg!(int)(_argptr));
		} else if(_arguments[i] == typeid(uint)) {
			str ~= Integer.toString(va_arg!(uint)(_argptr));
		} else if(_arguments[i] == typeid(ulong)) {
			str ~= Integer.toString(va_arg!(ulong)(_argptr));
		} else if(_arguments[i] == typeid(long)) {
			str ~= Integer.toString(va_arg!(long)(_argptr));
		} else if(_arguments[i] == typeid(float)) {
			str ~= Float.toString(va_arg!(float)(_argptr));
		} else if(_arguments[i] == typeid(double)) {
			str ~= Float.toString(va_arg!(double)(_argptr));
		} else if(_arguments[i] == typeid(byte)) {
			str ~= Integer.toString(va_arg!(byte)(_argptr));
		} else if(_arguments[i] == typeid(bool)) {
			str ~= Integer.toString(va_arg!(bool)(_argptr));
		} else if(_arguments[i] == typeid(char)) {
			str ~= Integer.toString(va_arg!(char)(_argptr));
		} else if(_arguments[i] == typeid(string) || _arguments[i] == typeid(char[])) {
			str ~= va_arg!(string)(_argptr);
		} else if(_arguments[i] == typeid(string*) || _arguments[i] == typeid(char[]*)) {
			str ~= *va_arg!(char[]*)(_argptr);
		} else {
			str ~= "unknown";
			//_arguments[i].print();
			break;
			
		}
	}
	
	return str;
}

alias stdoutln errorln;
alias stdoutln noticeln;

void stdoutln(...) {
	string str;
	for(size_t i = 0; i < _arguments.length; i++) {
		if(_arguments[i] == typeid(int)) {
			str ~= Integer.toString(va_arg!(int)(_argptr));
		} else if(_arguments[i] == typeid(uint)) {
			str ~= Integer.toString(va_arg!(uint)(_argptr));
		} else if(_arguments[i] == typeid(ulong)) {
			auto v = va_arg!(ulong)(_argptr);
			str ~= Integer.toString(v, v < uint.max ? "" : "x#");
		} else if(_arguments[i] == typeid(long)) {
			auto v = va_arg!(long)(_argptr);
			str ~= Integer.toString(v,  (v < int.max && v > int.min) ? "" : "x#");
		} else if(_arguments[i] == typeid(float)) {
			str ~= Float.toString(va_arg!(float)(_argptr));
		} else if(_arguments[i] == typeid(double)) {
			str ~= Float.toString(va_arg!(double)(_argptr));
		} else if(_arguments[i] == typeid(byte)) {
			str ~= Integer.toString(va_arg!(byte)(_argptr));
		} else if(_arguments[i] == typeid(bool)) {
			str ~= Integer.toString(va_arg!(bool)(_argptr));
		} else if(_arguments[i] == typeid(char)) {
			str ~= Integer.toString(va_arg!(char)(_argptr));
		} else if(_arguments[i] == typeid(string) || _arguments[i] == typeid(char[])) {
			str ~= va_arg!(string)(_argptr);
		} else if(_arguments[i] == typeid(string*) || _arguments[i] == typeid(char[]*)) {
			str ~= *va_arg!(char[]*)(_argptr);
		} else {
			str ~= "unknown";
			//_arguments[i].print();
			break;
			
		}
	}
	
	str ~= "\0";
	puts(str.ptr);
}

double microtime() {
	timeval tv;
	gettimeofday(&tv, null);
	return tv.tv_sec * cast(double)CLOCKS_PER_SEC +
		(tv.tv_usec * (1/(1000000 / cast(double)CLOCKS_PER_SEC)));
}

int parse_time_str(string time, string format = "%a, %d %b %Y %H:%M:%S") {
	tm t;
	string time0 = time~'\0';
	string format0 = format~'\0';
	
	auto plus = time.find_c('+');
	int tz_offset;
	if(plus != -1) {
		tz_offset = toInt(time[++plus .. $]);
	} else {
		auto minus = time.find_c('-');
		if(minus != -1) {
			tz_offset = -toInt(time[++minus .. $]);
		}
	}
	
	if(tz_offset) {
		tz_offset = (tz_offset / 100) * 3600;
	}
	
	strptime(time0.ptr, format0.ptr, &t);
	return mktime(&t) - tz_offset;
}

unittest {
	assert(parse_time_str("Sat, 19 Jun 2010 23:57:00 +0200") == 1276984620);
}

string html_entities(string str, bool escape = false) {
	str = replace_cs(str, '<', "&lt;");
	str = replace_cs(str, '>', "&gt;");
	str = replace_ss(str, "\r\n", "<br />");
	str = replace_cs(str, '\r', "<br />");
	str = replace_cs(str, '\n', "<br />");
	
	if(escape) {
		str = replace_cs(str, '\'', "\\'");
		str = replace_cs(str, '"', "\\\"");
	}
	
	return str;
}

//------------------------------------------------------
// library items (separate this out?)
//------------------------------------------------------

//TODO!!!! - write unittests for this function!
string clean_text(string text) {
	auto len = text.length;
	if(len) {
		char[] t = text ~ "        "; // the padding is for buffer overruns
		char[] new_text = " ";
		
		new_text.length = len+2;
		typeof(len) i = 0;
		typeof(len) cur = 0;
		
		// remove beginning spaces and newlines
		while(i < len && t[i] <= ' ') {
			i++;
		}
		
		assert(new_text[cur] == ' ');
		char in_quote = 0;
		bool tab = false;
		for(; i < len; i++) {
			if(t[i] < ' ') {
				if(t[i] == '\t') {
					tab = true;
				}
				
				if(t[i] == '\n') {
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
							i++;
						}
						
						continue;
					} else if(t[i+1] == '/') {
						while(i < len && t[i] != '\n') {
							i++;
						}
						
						continue;
					}
				}
				
				// get inside and outside of a quote
				if((t[i] == '"' || t[i] == '`') && t[i-1] != '\\') {
					if(in_quote != 0) {
						while(i < len && !(t[i] == in_quote && t[i-1] != '\\')) {
							new_text[++cur] = t[i++];
						}
						
						in_quote = 0;
					} else {
						in_quote = t[i];
					}
				}
				
				//errorln("t: ", i, " (", t.length, ") nt: ", cur, " ", new_text.length);
				if(!(t[i] == ' ' && new_text[cur] == ' ')) {
					if(tab) tab = false;
					new_text[++cur] = t[i];
				}
			}
		}
		
		if(new_text[cur] != ' ') {
			cur++;
		}
		
		return new_text[1 .. cur];
	} else {
		return text;
	}
}

void parse_cookie(inout string[string] options, string qs) {
	//TODO!!!! - write unittests for this function
	//OPTIMIZE! - surely this can be done faster... cleanse_url_string is slow.
	size_t len = qs.length;
	size_t eq = 0;
	size_t last_amp = 0;
	size_t i = 0;
	while(i < len) {
		if(eq == 0 && qs[i] == '=') {
			eq = i;
		}
		
		if((qs[i] == ' ' && qs[i-1] == ';') || i+1 == len) {
			if(i+1 == len) {
				i+=2;
			}
			
			string key;
			if(eq > last_amp) {
				key = qs[last_amp .. eq++];
			}
			
			if(eq > last_amp) {
				string value;
				options[key] = cleanse_url_string(qs[eq .. i-1]);
			}
			
			assert(i >= len || (qs[i] == ' ' && qs[i-1] == ';'));
			last_amp = i+1;  // plus 1, because it is the start of the string afte the amp
			eq = 0;
		}
		
		i++;
	}
}

// no return types, unless it's an array, then it returns the { ....
void parse_options(inout string[string] options, string text, bool string_quotes = false) {
	text = trim(text);
	auto text_len = text.length;
	
	assert(!options.length);
	options = null;
	if(text_len < 2) {
		return;
	}
	
	uint i = 0;
	while(text[i] == '{' && text[text_len-1] == '}') {
		text_len--;
		i++;
	}
	
	if(i > 0) {
		text = trim(text[i .. text_len]);
		text_len = text.length;
		i = 0;
	}
	
	for(;i < text_len; i++) {
		if(text[i] != ' ' && text[i] != ',') {
			
			// { label: "options, yeah", label2: `variable`, label3: {label1: "lala:", label2: `variable2`}}
			//	 ^^^^^
			uint start = i;
			while(text[i] != ':') {
				
				if(text[i] == ' ') {
					debug errorln("found a space in your label... expecting ':' in '" ~ text[start .. i] ~"'");
				}
				
				if(++i >= text_len) {
					//debug errorln("expected label... but not found '" ~ text[start .. i] ~ "'");
					return;
				}
			}
			
			string label = trim(text[start .. i]);
			if(label[0] == '\'' && label[$-1] == '\'') {
				label = label[1 .. $-1];
			}
			
			// { label: "options, yeah", label2: `variable`, label3: {label1: "lala:", label2: `variable2`}}
			//        ^
			
			i++;
			
			// { label: "options, yeah", label2: `variable`, label3: {label1: "lala:", label2: `variable2`}}
			//         ^
			
			while(text[i] == ' ') {
				if(++i >= text_len) {
					debug errorln("label has no value '" ~ text ~ "'");
					return;
				}
			}
			
			// { label: "options, yeah", label2: `variable`, label3: {label1: "lala:", label2: `variable2`}}
			//          ^
			
			uint def_start = i++;
			switch(text[def_start]) {
			case '{':
					// { label: "options, yeah", label2: `variable`, label3: {label1: "lala:", label2: `variable2`}}
					//														 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
				uint scopee = 1;
				while(true) {
					if(++i >= text_len) {
						debug errorln("cannot find end to text string in label '" ~ label ~ "'");
						return;
					}
					
					if(text[i] == '{') {
						scopee++;
					} else if(text[i] == '}') {
						if(scopee == 1) {
							break;
						}
						
						scopee--;
					}
					
					// skip text
					if(text[i] == '"' || text[i] == '`') {
						char delim = text[i];
						i++;
						if(i >= text_len) break; 
						while(text[i] != delim || (text[i] == delim && text[i-1] == '\\')) {
							if(++i >= text_len) {
								debug errorln("cannot find end to text string in label '" ~ label ~ "'");
								return;
							}
						}
					}
				}
				
				options[label] = trim(text[def_start .. i+1]);
				assert(trim(text[def_start .. i+1])[0] == '{');
				assert(trim(text[def_start .. i+1])[$-1] == '}');
				
			break;
			case '"', '`', '\'':
				// { label: "options, yeah", label2: `variable`, label3: {label1: "lala:", label2: `variable2`}}
				//			^^^^^^^^^^^^^^^          ^^^^^^^^^^
				char delim = text[def_start];
				string str;
				//TODO!!!! - make this utf8 compatible
				while(text[i] != delim || (text[i] == delim && text[i-1] == '\\')) {
					char c = text[i];
					if(c == delim && text[i-1] == '\\') {
						str[$-1] = delim;
					} else {
						str ~= c;
					}
					
					if(++i >= text_len) {
						debug errorln("cannot find end to text string in label '" ~ label ~ "'");
						return;
					}
				}
				
				if(string_quotes) {
					options[label] = '"' ~ str ~ '"';
				} else {
					options[label] = str;
				}
			break;
			default:
				// { label: "options, yeah", label2: variable, label3: {label1: "lala:", label2: `variable2`}}
				//									 ^^^^^^^^
				while(i < text_len && text[i] > ' ' && text[i] != ',') {
					++i;
				}
				
				options[label] = text[def_start .. i];
			}
		}
	}
}

string make_json(string[string] options) {
	string str;
	foreach(l, v; options) {
		str ~= l ~ ':' ~ v;
	}
	
	return str ? '{' ~ str ~ '}' : "{}";
}

string[] expressions(string inside, inout bool is_and) in {
	assert(inside == trim(inside));
} body {
	string[] exprs;
	int depth = 0;
	auto inside_length = inside.length;
	size_t first = 0;
	for(size_t k = 0; k < inside_length; k++) {
		char c = inside[k];
		if(c == '\'') {
			while(k < inside_length && inside[k] != '\'' && inside[k-1] != '\\') {
				k++;	
			}
		} else if(c == '"') {
			while(k < inside_length && inside[k] != '"' && inside[k-1] != '\\') {
				k++;	
			}
		} else if(c == '`') {
			while(k < inside_length && inside[k] != '`' && inside[k-1] != '\\') {
				k++;	
			}
		} else if(c == '(') {
			depth++;
		} else if(c == ')') {
			depth--;
		} else if(depth == 0 && ((inside[k] == '&' && inside[k+1] == '&') || (inside[k] == '|' && inside[k+1] == '|'))) {
			if(first == 0 || (is_and == true && inside[k] == '&') || (is_and != true && inside[k] == '|')) {
				is_and = (inside[k] == '&' ? true : false);
				exprs ~= trim(inside[first .. k-1]);
				k += 2;
				first = k;
			} else {
				debug errorln("Sorry, you cannot mix ANDs and ORs in the same logical expression");
			}
		}
	}
	
	if(first == 0) {
		// I assume the string is trimmed
		if(inside[0] == '(' && inside[$-1] == ')') {
			// useless parens... reprocess without them.
			//inside[0] = inside[$-1] = ' ';
			return expressions(inside[1 .. length-1], is_and);
		}
	}
	
	exprs ~= trim(inside[first .. $]);
	return exprs;
}


/*
void ordered_remove(T)(inout T t, ulong idx) {
	t = t[0 .. idx] ~ t[idx+1 .. $];
}

void unordered_remove(T)(inout T t, ulong idx) {
	ulong len = t.length;
	t[idx] = t[--len];
	t.length = len;
}
*/

float toFloat(in string s) {
	return Float.parse(s);
}

int toInt(string s) {
	auto len = s.length;
	int v = 0;
	if(len > 0) {
		for(int i = 0; i < len; i++) {
			char c = s[i];
			if(c >= '0' && c <= '9') {
				v = v * 10 + (c - '0');
			} else if(c == '.') {
				if(++i < len && s[i] > '4') {
					v++;
				}
			}
		}
		
		if(s[0] == '-') {
			v = -v;
		}
	}
	
	return v;
}

uint toUint(string s) {
	auto length = s.length;
	uint v = 0;
	for(int i = 0; i < length; i++) {
		char c = s[i];
		if(c >= '0' && c <= '9') {
			v = v * 10 + (c - '0');
		} else if(c == '.') {
			if(++i < length && s[i] > '4') {
				v++;
			}
		}
	}
	
	return v;
}

long toLong(string s) {
	auto length = s.length;
	long v = 0;
	if(length > 0) {
		for(int i = 0; i < length; i++) {
			char c = s[i];
			if(c >= '0' && c <= '9') {
				v = v * 10 + (c - '0');
			} else if(c == '.') {
				if(++i < length && s[i] > '4') {
					v++;
				}
			}
		}
		
		if(s[0] == '-') {
			v = -v;
		}
	}
	
	return v;
}

ulong toUlong(string s) {
	auto length = s.length;
	ulong v = 0;
	for(int i = 0; i < length; i++) {
		char c = s[i];
		if(c >= '0' && c <= '9') {
			v = v * 10 + (c - '0');
		} else if(c == '.') {
			if(++i < length && s[i] > '4') {
				v++;
			}
		}
	}
	
	return v;
}

uint from_hex(char c) {
    return (c <= '9') ? c - '0' :
	   (c <= 'F') ? c - 'A' + 10 :
			c - 'a' + 10;
}

string clearBr(string str) {
	string output;
	auto last_offset = 0;
	auto len = str.length;
	
	if(len >= 4) {
		output.length = len;
		output.length = 0;
		
		len -= 4; // this is to prevent buffer overruns
		
		ptrdiff_t i = 0;
		while(i < len) {
			char c = str[i];
			if(c == '<') {
				char c2 = str[i+1];
				if(c2 == 'b' || c2 == 'B') {
					char c3 = str[i+2];
					if(c3 == 'r' || c3 == 'R') {
						char c4 = str[i+3];
						if(c4 == '>') {
							output ~= str[last_offset .. i] ~ '\n';
							i += 3;
							last_offset = i +1;
						} else if(i+1 < len) {
							char c5 = str[i+4];
							if(c4 == '/' && c5 == '>') {
								output ~= str[last_offset .. i] ~ '\n';
								i += 4;
								last_offset = i + 1;
							} else if(i+2 < len) {
								char c6 = str[i+5];
								if(c4 == ' ' && c5 == '/' && c6 == '>') {
									output ~= str[last_offset .. i] ~ '\n';
									i += 5;
									last_offset = i + 1;
								}
							}
						}
					}
				}
			}
			
			i++;
		}
		
		output ~= str[last_offset .. $];
		
		return output;
	}
	
	return str;
}

unittest {
	assert(clearBr("la<br>la") == "la\nla");
	assert(clearBr("la<br/>la") == "la\nla");
	assert(clearBr("la<br />la") == "la\nla");
	assert(clearBr("la<BR>la") == "la\nla");
	assert(clearBr("la<BR/>la") == "la\nla");
	assert(clearBr("la<BR />la") == "la\nla");
}


// text functions, re-implemented to be binary safe and not throw exceptions
ptrdiff_t find_c(string str, char f, size_t offset = 0) {
	auto len = str.length;
	if(offset >= 0 && offset < len) {
		for(size_t i = offset; i < len; i++) {
			if(str[i] == f) {
				return i;
			}
		}
	}
	
	return -1;
}

ptrdiff_t find_s(string str, string f, int offset = 0) {
	auto len = str.length;
	auto flen = f.length;
	
	if(offset >= 0 && offset <= len - flen) {
restart:
		for(size_t i = offset; i < len; i++) {
			for(size_t j = i, k = 0; k < flen; j++, k++) {
				if(j >= len || str[j] != f[k]) {
					continue restart;
				}
			}
			
			return i;
		}
	}
	
	return -1;
}

ptrdiff_t findr_c(string str, char f, int offset = 0xb00bb00b) {
	auto len = cast(int) str.length - 1;
	if(offset == 0xb00bb00b || offset > len) {
		offset = len;
	}
	
	if(offset >= 0) {
		do {
			if(str[offset] == f) {
				return offset;
			}
		} while(offset-- != 0);
	}
	
	return -1;
}

ptrdiff_t findr_s(string str, string f, int offset = 0xb00bb00b) {
	auto len = str.length - 1;
	auto flen = f.length;
	if(offset == 0xb00bb00b || offset > len) {
		offset = len;
	}
	
	offset -= flen -1;
	
	if(offset >= 0) {
restart:
		do {
			for(size_t j = offset, k = 0; k < flen; j++, k++) {
				if(str[j] != f[k]) {
					continue restart;
				}
			}
			
			return offset;
		} while(offset-- != 0);
	}
	
	return -1;
}

string replace_cc(string str, char f, char r) {
	string output = null;
	auto len = str.length;
	for(uint i = 0; i < len; i++) {
		if(str[i] == f) {
			if(!output.length) {
				output = str.dup;
			}
			
			output[i] = r;
		}
	}
	
	return output.length ? output : str;
}

string replace_cs(string str, char f, string r) {
	string output;
	auto len = str.length;
	output.length = (len * r.length) >> 2;
	output.length = 0;
	
	// OPTIMIZE!! - this can be used by a steady increase of length in the string instead of concat operators
	for(size_t i = 0; i < len; i++) {
		char c = str[i];
		if(c == f) {
			output ~= r;
		} else {
			output ~= c;
		}
	}
	
	return output;
}

string replace_ss(string str, string f, string r) {
	string output;
	//OPTIMIZE!! - if the string sizes are the same, this can be optimized
	auto len = str.length;
	auto flen = f.length;
	output.length = (len * r.length) >> 2;
	output.length = 0;
	size_t i = 0;
	
restart:
	while(i < len) {
		//OPTIMIZE!! - if you save the last index, an operation can be done like in replace_sc
		for(size_t j = i, k = 0; j < len && k < flen; j++, k++) {
			if(str[j] != f[k]) {
				output ~= str[i++];
				continue restart;
			}
		}
		
		i += flen;
		output ~= r;
	}
	
	return output;
}

string replace_sc(string str, string f, char r) {
	string output = null;
	auto len = str.length;
	auto flen = f.length;
	output.length = len;
	output.length = 0;
	size_t i = 0;
	size_t j;
	
restart:
	while((j = str.find_s(f, i)) != -1) {
		output ~= str[i .. j] ~  r;
		i = j + flen;
	}
	
	if(output.length) {
		if(i < len) {
			output ~= str[i .. $];
		}
		
		return output;
	} else {
		return str;
	}
}

string remove_c(string str, char f) {
	string output;
	auto len = str.length;
	output.length = len;
	output.length = 0;
	size_t i = 0;
	size_t j;
	
restart:
	while(true) {
		j = str.find_c(f, i);
		if(j != -1) {
			output ~= str[i .. j];
			i = ++j;
		} else {
			break;
		}
	}
	
	if(i < len) {
		output ~= str[i .. $];
	}
	
	return output;
}

string remove_s(string str, string f) {
	string output;
	auto len = str.length;
	auto flen = f.length;
	output.length = len;
	output.length = 0;
	size_t i = 0;
	size_t j;
	
restart:
	while(true) {
		j = str.find_s(f, i);
		if(j != -1) {
			output ~= str[i .. j];
			i = j + flen;
		} else {
			break;
		}
	}
	
	if(i < len) {
		output ~= str[i .. $];
	}
	
	return output;
}

string trim(string str) {
	int j = cast(int)str.length-1;
	if(j != -1) {
		int i = 0;
		
		while(j != -1 && str[j] <= ' ') {
			j--;
		}
		
		while(i < j && str[i] <= ' ') {
			i++;
		}
		
		if(j != -1) {
			return str[i .. j+1];
		}
	}
	
	return null;
}

string strip_search(string str) {
	bool add_j = false;
	auto len = str.length;
	string output;
	output.length = len;
	output = "%";
	size_t i = 0;
	
	if(len) {
		do {
			if(str[i] >= 'A' && str[i] <= 'Z') {
				output ~= str[i] + 0x20;
				add_j = true;
			} else if((str[i] >= 'a' && str[i] <= 'z') || (str[i] >= '0' && str[i] <= '9')) {
				output ~= str[i];
				add_j = true;
			} else {
				if(add_j) {
					output ~= '%';
					add_j = false;
				}
			}
		} while(++i < len)
		
		if(add_j == true) {
			output ~= '%';
		}
	}
	
	return output;
}

ptrdiff_t find_noquote(string s, char needle, int offset = 0) {
	char prev_c = offset != 0 ? s[offset-1] : 0;
	char quote = 0;
	auto end = s.length;
	for(size_t j = offset; j < end; j++) {
		char c = s[j];
		if(c == '\'' && prev_c != '\\') {
			if(quote == '\'') {
				quote = 0;
			} else if(quote == 0) {
				quote = '\'';
			}
		} else if(c == '"' && prev_c != '\\') {
			if(quote == '"') {
				quote = 0;
			} else if(quote == 0) {
				quote = '"';
			}
		} else if(c == '`' && prev_c != '\\') {
			if(quote == '`') {
				quote = 0;
			} else if(quote == 0) {
				quote = '`';
			}
		} else if(quote == 0 && c == needle) {
			return j;
		}
		
		prev_c = c;
	}
	
	return -1;
}

ptrdiff_t find_noquote(string s, string needle, int offset = 0) {
	char prev_c = offset != 0 ? s[offset-1] : 0;
	char quote = 0;
	auto len = needle.length;
	auto end = s.length - len +1;
	
	for(size_t j = offset; j < end; j++) {
		char c = s[j];
		if(c == '\'' && prev_c != '\\') {
			if(quote == '\'') {
				quote = 0;
			} else if(quote == 0) {
				quote = '\'';
			}
		} else if(c == '"' && prev_c != '\\') {
			if(quote == '"') {
				quote = 0;
			} else if(quote == 0) {
				quote = '"';
			}
		} else if(c == '`' && prev_c != '\\') {
			if(quote == '`') {
				quote = 0;
			} else if(quote == 0) {
				quote = '`';
			}
		} else if(quote == 0 && s[j .. j+len] == needle) {
			return j;
		}
		
		prev_c = c;
	}
	
	return -1;
}

string cleanse_url_string(char[] text) {
	char[] text2 = cast(char[])replace_sc(text, "%0D%0A", '\n');
	size_t len = text2.length;
	
	size_t j = 0;
	
	//foreach(i; 0 .. text2.length) {
	for(size_t i = 0; i < len; i++) {
		char c = text2[i];
		if(c == '%') {
			uint c2;
			
			c2 = from_hex(text2[i+2]);
			c2 += from_hex(text2[++i]) * 16;
			i++;
			c = cast(char)c2;
		} else if(c == '+') {
			c = ' ';
		}
		
		text2[j++] = c;
	}
	
	text2.length = j;
	return text2;
}

string between(string str, char left, string right, int offset = 0) {
	string output = null;
	if(str.length) {
		auto i = str.find_c(left, offset);
		if(i != -1) {
			i++;
			auto i_end = str.find_s(right, i);
			if(i_end != -1) {
				output = str[i .. i_end];
			}
		}
	}
	
	return output;
}

string between(string str, string left, string right, int offset = 0) {
	string output = null;
	if(str.length) {
		auto i = str.find_s(left, offset);
		if(i != -1) {
			i += left.length;
			auto i_end = str.find_s(right, i);
			if(i_end != -1) {
				output = str[i .. i_end];
			}
		}
	}
	
	return output;
}

string before(string str, string search, int offset = 0) {
	string output = null;
	
	if(str.length) {
		auto i = str.find_s(search, offset);
		if(i != -1) {
			output = str[offset .. i];
		}
	}
	
	return output;
}

string after(string str, string search, int offset = 0) {
	string output = null;
	
	if(str.length) {
		auto i = str.find_s(search, offset);
		if(i != -1) {
			output = str[i + search.length .. $];
		}
	}
	
	return output;
}

string until(string str, string search, int offset = 0) {
	string output = null;
	
	if(str.length) {
		auto i = str.find_s(search, offset);
		if(i != -1) {
			output = str[offset .. i];
		}
	}
	
	return output;
}

string join(string[] str, char c) {
	string output = null;
	foreach(s; str) {
		if(output.length) {
			output ~= c;
		}
		
		output ~= s; 
	}
	
	return output;
}

string join(string[string] options, char keyval_separator, char item_separator) {
	string output = null;
	
	foreach(key, val; options) {
		if(output.length) {
			output ~= item_separator;
		}
		
		output ~= key~keyval_separator~val;
		
	}
	
	return output;
}

string join(string[string] options, char keyval_separator, string item_separator) {
	string output = null;
	
	foreach(key, val; options) {
		if(output.length) {
			output ~= item_separator;
		}
		
		output ~= key~keyval_separator~val;
		
	}
	
	return output;
}

string to_url(string[string] options) {
	string output = null;
	
	foreach(key, val; options) {
		if(output.length) {
			output ~= '&';
		}
		
		output ~= key~'='~val;
		
	}
	
	return output;
}

//const string tostring = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-";
const string tostring = "0y23456789ancdsfghJiklmKopqretuvwC1zABxDEFGHIjNLMbOPQRSTUVWXYZ_-";

string ctfe_enc_int(size_t num) {
	string result;
	// bits 1-6 bits
	result ~= tostring[num & 0x3f];
	if(num > 0x3f) { // bits 7-12
		num >>= 6;
		result ~= tostring[num & 0x3f];
		while(num > 0x3f) { // bits 13-66
			num >>= 6;
			result ~= tostring[num & 0x3f];
		}
	}
	
	return result;
}


string rand_str(int size, size_t seed = 0) in {
	assert(size <= 60);
} body {
	size_t num = rand() + seed;
	char[60] result;
	
	result[0] = tostring[num & 0x3f];
	size_t i = 1;
	while(i < size) {
		num >>= 6;
		if(num < 0x3f) {
			num += rand();
		}
		
		result[i++] = tostring[num & 0x3f];
	}
	
	return result[0 .. i].dup;
}

string enc_int(ulong num, size_t len = 0) {
	size_t i = 0;
	char[12] result = '0';
	// bits 1-6 bits
	result[i++] = tostring[cast(size_t)(num & 0x3f)];
	if(num > 0x3f) { // bits 7-12
		num >>= 6;
		result[i++] = tostring[cast(size_t)(num & 0x3f)];
		while(num > 0x3f) { // bits 13-66
			num >>= 6;
			result[i++] = tostring[cast(size_t)(num & 0x3f)];
		}
	}
	
	if(i < len && len <= 12) {
		i = len;
	}
	
	return result[0 .. i].dup;
}

char enc_char(int num) {
	size_t i = 0;
	return tostring[num & 0x3f];
}

ulong dec_int(string num) {
	auto i = num.length;
	ulong result;
	if(i > 0) {
		// bits 1-6 bits
		result = tostring.find_c(num[--i]);
		while(i > 0) { // bits 7-36
			result <<= 6;
			result += tostring.find_c(num[--i]);
		}
	}
	
	return result;
}

int dec_int(char num) {
	ulong result;
	// bits 1-6 bits
	result = tostring.find_c(num);
	
	
	return cast(int)result;
}


const ubyte[256] UTF8_BYTES_NEEDED =
	[
		1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
		1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
		1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
		1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
		1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
		1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
		0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
		1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
		0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
		0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
		0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
		0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
		2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
		2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
		3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		4,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0
	];

int stride(char c) {
	if(c < 128) {
		return 1;
	} else {
		return UTF8_BYTES_NEEDED[c];
	}
}

/*
 * Macros for various sorts of alignment and rounding when the alignment
 * is known to be a power of 2.
 *
#define	P2ALIGN(x, align)		((x) & -(align))
#define	P2PHASE(x, align)		((x) & ((align) - 1))
#define	P2NPHASE(x, align)		(-(x) & ((align) - 1))
#define	P2ROUNDUP(x, align)		(-(-(x) & -(align)))
#define	P2END(x, align)			(-(~(x) & -(align)))
#define	P2PHASEUP(x, align, phase)	((phase) - (((phase) - (x)) & -(align)))
#define	P2CROSS(x, y, align)		(((x) ^ (y)) > (align) - 1)
 *
 * Determine whether two numbers have the same high-order bit.
 *
#define	P2SAMEHIGHBIT(x, y)		(((x) ^ (y)) < ((x) & (y)))
 */

// Tango is kind of lame, so I made some compatability functions

int exec(string cmd) {
	//auto p = new Process(cmd, null);
	//p.execute();
	//return p.wait();
	cmd ~= '\0';
	return system(cmd.ptr);
}

void mkdir(string dir) {
	FilePath fp = new FilePath(dir);
	if(fp.exists) {
		fp.remove();
	}
	
	fp.createFolder();
}

void scan_dir(FilePath src, bool function(FilePath p) dg, int levels = 0) {
	foreach(info; src) {
		FilePath p = FilePath.from(info);
		if(p.isFolder) {
			if(levels > 0) {
				scan_dir(p, dg, --levels);
			}
		} else {
			if(!dg(p)) {
				throw new Exception("canceled");
			}
		}
		
		delete p;
	}
}

void scan_dir(FilePath src, bool delegate(FilePath p) dg) {
	foreach(info; src) {
		FilePath p = FilePath.from(info);
		if(p.isFolder) {
			scan_dir(p, dg);
		} else {
			if(!dg(p)) {
				throw new Exception("canceled");
			}
		}
	}
}

