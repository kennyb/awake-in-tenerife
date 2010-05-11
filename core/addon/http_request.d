module addon.http_request;

import tango.stdc.posix.unistd;
import tango.stdc.string : memcpy;

import tango.text.xml.Document;

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
	
	static ubyte[4] ip[string][];
	string req_header;
	string output_header;
	string output;
	string host;
	ubyte[4][] ips;
	
	static this() {
		static char seed[128];
		dns_random_init(&seed[0]);
		ip["localhost"] ~= [127, 0 , 0, 1];
	}
	
	this(string host, string header = null) {
		this.host = host;
		if(header.length) {
			req_header = trim(header) ~ "\r\n\r\n";
		} else {
			req_header = "\r\n\r\n";
		}
		
		// resolve the dns of that host
		if(!(host in ip)) {
			resolve();
		} else {
			ips = ip[host];
		}
	}
	
	void resolve() {
		string host2 = host ~ "\0";
		ubyte[16] hosts;
		auto ret = resolve_ip4(host2.ptr, hosts.ptr, 4);
		if(ret > 0) {
			while(ret-- > 0) {
				size_t i = ret << 2;
				ubyte[4] j = hosts[i .. i + 4];
				debug stdoutln("found: ", cast(int)j[0], ".", cast(int)j[1], ".", cast(int)j[2], ".", cast(int)j[3]);
				ip[host] ~= j;
			}
			
			ips = ip[host];
		} else {
			output = "could not find host";
		}
	}
	
	int get(string uri, ushort port = 80) {
		string request = "GET /";
		if(uri.length >= 1) {
			if(uri[0] == '/') {
				request ~= uri[1 .. $];
			} else {
				request ~= uri;
			}
			
			request ~= " HTTP/1.0\r\nConnection: close\r\nAccept-Encoding:\r\nAccept: text/plain\r\nHost: " ~ host ~ "\r\n" ~ req_header;
			auto s = socket_tcp4b();
			
			for(uint i = 0; i < ips.length; i++) {
				auto ret = socket_connect4(s, cast(char*)ips[i].ptr, port);
			
				if(ret >= 0) {
				
					int cur;
					while((ret = write(s, request.ptr, request.length)) >= 0) {
						cur += ret;
						if(cur == request.length) {
							output.length = 0;
							cur = 0;
							char[1024] tmp;
							while((ret = read(s, tmp.ptr, 1024)) >= 0) {
								if(ret == 0) {
									io_close(s);
									return parse();
								}
								
								output.length = output.length + ret;
								memcpy(&output[cur], tmp.ptr, ret);
								cur += ret;
							}
						}
					}
				}
			}
			
			io_close(s);
		}
		
		return 0;
	}
	
	int post(string uri) {
		stdoutln("TODO!! - implement posting");
		return -1;
	}
	
	private int parse() {
		if(output.length > "HTTP/1.0 ".length) {
			auto loc = find_s(output, "\r\n\r\n");
			if(loc != -1) {
				loc += 4;
				if(output.length > loc) {
					int ret = toUint(output["HTTP/1.0 ".length .. "HTTP/1.0 ".length+3]);
					output_header = trim(output[0 .. loc]);
					if(find_s(output_header, "Content-Encoding: gzip") == -1) {
						output = output[loc .. $];
					} else {
						stdoutln("cannot uncompress gzip!");
						output = output[loc .. $];
					}
					
					return ret;
				}
			}
		}
		
		return FAILURE;
	}
}

