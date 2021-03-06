import vibe.d;

import vibelog.vibelog;

import std.algorithm;
import std.datetime;


string[] s_moduleNames;
Json[string] s_modules;
Json[] s_projectTree;

void download(HttpServerRequest req, HttpServerResponse res)
{
	if( "file" in req.query )
		res.redirect("/files/"~req.query["file"]);
	else res.renderCompat!("download.dt", HttpServerRequest, "req")(Variant(req));
}

void api(HttpServerRequest req, HttpServerResponse res)
{
	string moduleName = req.params["modulename"];

	auto pm = moduleName in s_modules;
	if( pm is null ) return;

	res.renderCompat!("apimodule.dt",
		HttpServerRequest, "req",
		string[], "moduleNames",
		Json[string], "modules",
		Json[], "projectTree",
		string, "moduleName")
		(Variant(req), Variant(s_moduleNames), Variant(s_modules), Variant(s_projectTree), Variant(moduleName));
}

void error(HttpServerRequest req, HttpServerResponse res, HttpServerErrorInfo error)
{
	res.renderCompat!("error.dt",
		HttpServerRequest, "req",
		HttpServerErrorInfo, "error")
		(Variant(req), Variant(error));
}

void updateDocs()
{
	try { 
		import std.file;
		string text = readText("docs.json");
		auto json = parseJson(text);
		//s_projectTree = cast(Json[])json;
		foreach( m; json ){
			auto mname = m.name.get!string;
			s_moduleNames ~= mname;
			s_modules[mname] = m;
		}
		s_moduleNames.sort();
	} catch( Exception e ){
		logError("Error loading docs: %s", e.toString());
		throw e;
	}
}

void addCacheHeader(HttpServerRequest req, HttpServerResponse res)
{
	long maxAge = 60*60; // 1 hr
	auto expireTime = Clock.currTime().toUTC() + dur!"seconds"(maxAge);
	res.headers["Expires"] = toRFC822DateTimeString(expireTime);
	res.headers["Cache-Control"] = "max-age="~to!string(maxAge);
}

static this()
{
	updateDocs();

	auto settings = new HttpServerSettings;
	settings.hostName = "vibed.org";
	settings.port = 8003;
	settings.bindAddresses = ["127.0.0.1"];
	settings.errorPageHandler = toDelegate(&error);
	
	auto router = new UrlRouter;
	
	router.get("*", &addCacheHeader);
	router.get("/",          staticTemplate!"home.dt");
	router.get("/about",     staticTemplate!"about.dt");
	router.get("/contact",   staticTemplate!"contact.dt");
	router.get("/impressum",   staticTemplate!"impressum.dt");
	router.get("/download",  &download);
	router.get("/features",  staticTemplate!"features.dt");
	router.get("/docs",      staticTemplate!"docs.dt");
	router.get("/developer", staticTemplate!"developer.dt");
	router.get("/templates", staticTemplate!"templates.dt");
	router.get("/api/:modulename", &api);

	auto blogsettings = new VibeLogSettings;
	blogsettings.configName = "vibe.d";
	blogsettings.basePath = "/blog/";
	registerVibeLog(blogsettings, router);

	router.get("*", serveStaticFiles("./public/"));
	
	listenHttp(settings, router);
}
