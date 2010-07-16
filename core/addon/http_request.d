module addon.http_request;

import tango.stdc.posix.unistd;
import tango.stdc.string : memcpy;

import tango.text.xml.Document;
import tango.sys.Process : Process, ProcessCreateException;
import tango.io.device.File : File;
import Path = tango.io.Path;

import libowfat;
import lib;
extern(C) int resolve_ip4(char* host, ubyte* results, int max);

unittest {
	//HttpRequest http = new HttpRequest("localhost");
	//int ret = http.get("/");
	
	/*
	// test video API
	HttpRequest http = new HttpRequest("gdata.youtube.com");
	int ret = http.get("/feeds/videos/sQ7dgUL5CmI");
	stdoutln("result: ", ret, "\n", http.output);
	if(ret) {
		auto doc = new Document!(char);
		doc.parse(http.output);
		
		stdoutln("has ", doc.query.descendant.count, " items");
		auto set = doc.query.descendant["media:title"];
		stdoutln("found: ", set.count, " ", set[0].nodes[0].value);
		
		
		set = doc.query["entry"]["media:group"]["media:title"];
		stdoutln("found: ", set.count, " ", set[0].nodes[0].value);
		//http = new HttpRequest("kenny.tuenti.local");
	}
	*/
}

class HttpRequest {
	
	static private ubyte[4] ip[string][];
	private string req_header;
	private string host;
	private ubyte[4][] ips;
	private string filename;
	public string output_header;
	public string output;
	public string error;
	public int status;
	public string[string] cookie;
	public int timeout = 5;
	public bool fresh_cookies = true;
	
	static this() {
		exec("rm -f /tmp/http_request.*");
		static char seed[128];
		dns_random_init(&seed[0]);
		ip["localhost"] ~= [127, 0 , 0, 1];
	}
	
	this(string host, string header = null) {
		this.host = host;
		this.filename = "/tmp/http_request." ~ rand_str(40).remove('-');
		if(header.length) {
			req_header = trim(header) ~ "\r\n\r\n";
		} else {
			req_header = "\r\n\r\n";
		}
		
		// resolve the dns of that host
		//if(!(host in ip)) {
		//	resolve();
		//} else {
		//	ips = ip[host];
		//}
	}
	
	~this() {
		
	}
	
	private void resolve() {
		string host2 = host ~ "\0";
		ubyte[16] hosts;
		auto ret = resolve_ip4(host2.ptr, hosts.ptr, 4);
		if(ret > 0) {
			while(ret-- > 0) {
				size_t i = ret << 2;
				ubyte[4] j = hosts[i .. i + 4];
				//debug stdoutln("found: ", cast(int)j[0], ".", cast(int)j[1], ".", cast(int)j[2], ".", cast(int)j[3]);
				ip[host] ~= j;
			}
			
			ips = ip[host];
		} else {
			output = "could not find host";
		}
	}
	
	public int get(string uri, ushort port = 80, bool tidy_it = false) {
		string[] curl_args;
		status = FAILURE;
		string header_file = filename ~ ".header";
		string cookies_file = fresh_cookies ? filename ~ ".cookies" : "/tmp/http_request."~host~".cookies";
		
		string[] curl_cmd;// = `curl --silent -o ` ~ filename;
		curl_cmd ~= "curl";
		curl_cmd ~= "--compressed";
		//curl_cmd ~= "-A";
		//curl_cmd ~= "Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.2.6) Gecko/20100627 Gentoo Firefox/3.6.6";
		//curl_cmd ~= "-s"; // silent
		curl_cmd ~= "-v"; // verbose
		curl_cmd ~= "-i"; // include headers in output
		curl_cmd ~= "-L"; // follow location hints
		curl_cmd ~= "-D"; // output header to file:
		curl_cmd ~= header_file;
		curl_cmd ~= "-c";
		curl_cmd ~= cookies_file;
		curl_cmd ~= "-m";
		curl_cmd ~= Integer.toString(timeout);
		if(!fresh_cookies) {
			curl_cmd ~= "-b"; // read cookies from this file:
			curl_cmd ~= cookies_file;
		}
		
		if(port != 80) {
			uri ~= ":"~Integer.toString(port);
		}
		
		ptrdiff_t nl;
		ptrdiff_t last = 0;
		while((nl = req_header.find("\r\n", last)) != -1) {
			auto h = req_header[last .. nl].trim();
			last = nl+2;
			if(h.length && h.find("Cookie: ") != 0) {
				curl_cmd ~= "-H";
				curl_cmd ~= '"'~h~'"';
			}
		}
		
		auto i_existing_cookie = req_header.find("\r\nCookie: ");
		if(i_existing_cookie != -1) {
			auto existing_cookie = req_header.between("\r\nCookie: ", "\r\n", i_existing_cookie).trim();
			if(existing_cookie.length) {
				noticeln("parsing existing cookie: ", existing_cookie);
				cookie.parse_cookie(existing_cookie);
				req_header = req_header[0 .. i_existing_cookie] ~ req_header[i_existing_cookie + existing_cookie.length .. $];
			}
		}
		
		if(cookie.length) {
			auto new_cookie = cookie.join('=', "; ");
			req_header ~= "\r\nCookie: " ~ new_cookie;
			curl_cmd ~= "-H";
			curl_cmd ~= `"Cookie: ` ~ new_cookie~'"';
		}
		
		curl_cmd ~= "-o";
		curl_cmd ~= filename;
		curl_cmd ~= `http://`~host~uri;
		
		//try {
			//File.set(cookies_file, "");
			noticeln("exec: ", curl_cmd.join(' '));
			auto p_curl = new Process(curl_cmd, null);
			
			p_curl.execute();
			p_curl.wait;
			delete p_curl;
			
			
		//} catch(Exception e) {
		//	noticeln(e.toString());
		//	return FAILURE;
		//}
		
		if(!Path.exists(filename)) {
			return 408;
		}
		
		//output_header = trim(cast(string) File.get(filename~".header"));
		output = cast(string) File.get(filename);
		
		output_header = null;
		error = null;
		
		auto loc = find(output, "\r\n\r\n");
		if(loc != -1) {
			loc += 4;
			if(output.length > loc) {
				status = toUint(output["HTTP/1.0 ".length .. "HTTP/1.0 ".length+3]);
				this.output_header = trim(output[0 .. loc]);
				
				size_t i_last = 0;
				ptrdiff_t i_cookie;
				ptrdiff_t i_cookie_end;
				while(
						(i_cookie = output_header.find("\r\nSet-Cookie: ", i_last)) != -1 &&
						(i_cookie += "\r\nSet-Cookie: ".length) < output_header.length &&
						(i_cookie_end = output_header.find("; ", i_cookie)) != -1
					) {
					cookie.parse_cookie(output_header[i_cookie .. i_cookie_end]);
					i_last = i_cookie_end;
				}
				
				string set_cookie = output_header.between("\r\nSet-Cookie: ", "; ").trim();
				if(set_cookie.length) {
					cookie.parse_cookie(set_cookie);
					set_cookie = cookie.to_url();
					
					auto existing_cookie = req_header.find("\r\nCookie: ");
					if(existing_cookie == -1) {
						req_header ~= "\r\nCookie: " ~ set_cookie;
					} else {
						existing_cookie += "\r\nCookie: ".length;
						auto end_cookie = req_header.find("\r\n", existing_cookie);
						if(end_cookie != -1) {
							req_header = req_header[0 .. existing_cookie] ~ set_cookie ~ req_header[end_cookie .. $];
						}
					}
				}
				
				/+
				string url = output_header.between("\r\nLocation: ", "\r\n").trim();
				if(url.length) {
					string host = url.after("://");
					url = '/' ~ host.after("/");
					host = host.before("/");
					
					if(host == null) {
						host = this.host;
						if(url[0] != '/') {
							error = `a relative path redirect needs to begin with a /`;
							return FAILURE;
						}
					}
					
					auto http = new typeof(this)(host, req_header);
					return http.get(url);
				}
				+/
				
				if(find(output_header, "Content-Encoding: gzip") == -1) {
					output = output[loc .. $];
				} else {
					stdoutln("cannot uncompress gzip!");
					output = output[loc .. $];
				}
				
				//File.set(filename, output);
				Path.remove(filename);
				Path.remove(header_file);
				if(fresh_cookies) {
					Path.remove(cookies_file);
				}
				
				if(tidy_it) {
					noticeln("tidying... ", output[0 .. 50]);
					File.set(filename ~ ".tidy", output.replace('\n', ' ').remove('\r'));
					auto p_tidy = new Process(`tidy -w 10000 -asxhtml -n -b -utf8 -m ` ~ filename ~ ".tidy", null);
					scope(exit) delete p_tidy;
					p_tidy.execute();
					p_tidy.wait;
					output = (cast(string) File.get(filename ~ ".tidy")).replace('\n', ' ').remove('\r');
					Path.remove(filename ~ ".tidy");
					Path.remove(filename ~ ".tidy.err");
				}
				
				noticeln("output: ", output.length);
				return status;
			}
		}
		
		error = `empty response`;
		return FAILURE;
		
		
		/*
		string request = "GET /";
		output = null;
		if(uri.length >= 1) {
			if(uri[0] == '/') {
				request ~= uri[1 .. $];
			} else {
				request ~= uri;
			}
			
			request ~= " HTTP/1.0\r\nConnection: close\r\nContent-Type: text/xml; charset=utf-8\r\nAccept-Encoding:\r\nAccept: text/plain\r\nHost: " ~ host ~ "\r\n" ~ req_header;
			debug noticeln("--->\n", request.trim(), " ...");
			auto s = socket_tcp4b();
			auto d = io_fd(s);
			
			if(d) {
				//tai6464 t;
				//taia_now(&t);
				//taia_addsec(&t, &t, 1);
				//io_timeout(d, t);
				
				for(uint i = 0; i < ips.length; i++) {
					auto ret = socket_connect4(s, cast(char*)ips[i].ptr, port);
				
					if(ret >= 0) {
					
						int cur;
						while((ret = write(s, request.ptr, request.length)) >= 0) {
							cur += ret;
							if(cur == request.length) {
								output.length = 0;
								cur = 0;
								//OPTIMIZE!! - this can probably be read directly into the string
								char[1024] tmp;
								while((ret = read(s, tmp.ptr, 1024)) >= 0) {
									if(ret == 0) {
										io_close(s);
										delete request;
										return parse();
									}
									
									output.length = output.length + ret;
									memcpy(&output[cur], tmp.ptr, ret);
									cur += ret;
								}
							}
						}
					} else {
						errorln("unable to connect to ", host);
					}
				}
			}
			
			io_close(s);
		}
		
		delete request;
		return 0;
		*/
	}
	
	public int post(string uri) {
		stdoutln("TODO!! - implement posting");
		return -1;
	}
	
	//private int parse(bool tidy_it) {
		
	//}
}

