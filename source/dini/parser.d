/**
 * INI parsing functionality.
 *
 * Examples:
 * ---
 * auto ini = Ini.ParseString("test = bar")
 * writeln("Value of test is ", ini["test"]);
 * ---
 */
module dini.parser;

import std.algorithm : min, max, countUntil;
import std.array     : split, replaceInPlace, join;
import std.file      : readText;
import std.stdio     : File;
import std.string    : strip, splitLines;
import std.traits    : isSomeString;
import std.range     : ElementType;
import std.conv      : to;
import dini.reader   : UniversalINIReader, INIException, INIToken;


/**
 * Represents ini section
 *
 * Example:
 * ---
 * Ini ini = Ini.Parse("path/to/your.conf");
 * string value = ini.getKey("a");
 * ---
 */
struct IniSection
{
    /// Section name
    protected string         _name = "root";
    
    /// Parent
    /// Null if none
    protected IniSection*    _parent;
    
    /// Childs
    protected IniSection[string] _sections;
    
    /// Keys
    protected string[string] _keys;
    
    
    
    /**
     * Creates new IniSection instance
     *
     * Params:
     *  name = Section name
     */
    public this(string name)
    {
        _name = name;
        _parent = null;
    }
    
    
    /**
     * Creates new IniSection instance
     *
     * Params:
     *  name = Section name
     *  parent = Section parent
     */
    public this(string name, IniSection* parent)
    {
        _name = name;
        _parent = parent;
    }
    
    /**
     * Sets section key
     *
     * Params:
     *  name = Key name
     *  value = Value to set
     */
    public void setKey(string name, string value)
    {
        _keys[name] = value;
    }
    
    /**
     * Checks if specified key exists
     *
     * Params:
     *  name = Key name
     *
     * Returns:
     *  True if exists, false otherwise 
     */
    public bool hasKey(string name) @safe nothrow @nogc
    {
        return (name in _keys) !is null;
    }
    
    /**
     * Gets key value
     *
     * Params:
     *  name = Key name
     *
     * Returns:
     *  Key value
     *
     * Throws:
     *  IniException if key does not exists
     */
    public string getKey(string name)
    {
        if(!hasKey(name)) {
            throw new IniException("Key '"~name~"' does not exists");
        }
        
        return _keys[name];
    }
    
    
    /// ditto
    alias getKey opCall;
    
    /**
     * Gets key value or defaultValue if key does not exist
     *
     * Params:
     *  name = Key name
     *  defaultValue = Default value
     *
     * Returns:
     *  Key value or defaultValue
     *
     */
    public string getKey(string name, string defaultValue) @safe nothrow
    {
        return hasKey(name) ? _keys[name] : defaultValue;
    }
    
    /**
     * Removes key
     *
     * Params:
     *  name = Key name
     */
    public void removeKey(string name)
    {
        _keys.remove(name);
    }
    
    /**
     * Adds section
     *
     * Params:
     *  section = Section to add
     */
    public void addSection(ref IniSection section)
    {
        if (hasSection(section._name)) {
            foreach (key; section._keys.keys) {
                _sections[section._name]._keys[key] = section._keys[key];
            }
        } else {
	        _sections[section._name] = section;
        }
    }
    
    /**
     * Checks if specified section exists
     *
     * Params:
     *  name = Section name
     *
     * Returns:
     *  True if exists, false otherwise 
     */
    public bool hasSection(string name)
    {
        if (name in _sections) {
            return true;
        }
        return false;
    }
    
    /**
     * Returns reference to section
     *
     * Params:
     *  Section name
     *
     * Returns:
     *  Section with specified name
     */
    public ref IniSection getSection(string name)
    {
        if (!(hasSection(name))) {
            throw new IniException("Section '"~name~"' does not exists");
        }
        return _sections[name];
    }
    
    
    /// ditto
    public alias getSection opIndex;
    
    /**
     * Removes section
     *
     * Params:
     *  name = Section name
     */
    public void removeSection(string name)
    {
        if (!(hasSection(name))) {
            return;
        }
        _sections.remove(name);
    }
    
    /**
     * Section name
     *
     * Returns:
     *  Section name
     */
    public string name() @property
    {
        return _name;
    }
    
    /**
     * Array of keys
     *
     * Returns:
     *  Associative array of keys
     */
    public string[string] keys() @property
    {
        return _keys;
    }
    
    /**
     * Associative array of sections
     *
     * Returns:
     *  Array of sections
     */
    public IniSection[string] sections() @property
    {
        return _sections;
    }
    
    /**
     * Root section
     */
    public IniSection root() @property
    {
        IniSection s = this;
        
        while(s.getParent() != null)
            s = *(s.getParent());
        
        return s;
    }
    
    /**
     * Section parent
     *
     * Returns:
     *  Pointer to parent, or null if parent does not exists
     */
    public IniSection* getParent()
    {
        return _parent;
    }
    
    /**
     * Checks if current section has parent
     *
     * Returns:
     *  True if section has parent, false otherwise
     */
    public bool hasParent()
    {
        return _parent != null;
    }
    
    /**
     * Moves current section to another one
     *
     * Params:
     *  New parent
     */
    public void setParent(ref IniSection parent)
    {
        _parent.removeSection(this.name);
        _parent = &parent;
        parent.addSection(this);
    }
    
    
    /**
     * Parses filename
     *
     * Params:
     *  filename = Configuration filename
     *  doLookups = Should variable lookups be resolved after parsing? 
     */
    public void parse(string filename, bool doLookups = true)
    {
        parseString(readText(filename), doLookups);
    }

    public void parse(File* file, bool doLookups = true)
    {
        string data = file.byLine().join().to!string;
        parseString(data, doLookups);
    }

    public void parseWith(Reader)(string filename, bool doLookups = true)
    {
        parseStringWith!Reader(readText(filename), doLookups);
    }

    public void parseWith(Reader)(File* file, bool doLookups = true)
    {
        string data = file.byLine().join().to!string;
        parseStringWith!Reader(data, doLookups);
    }

    public void parseString(string data, bool doLookups = true)
    {
        parseStringWith!UniversalINIReader(data, doLookups);
    }

    public void parseStringWith(Reader)(string data, bool doLookups = true)
    {
        IniSection* section = &this;

        auto reader = Reader(data);
        alias KeyType = reader.KeyType;
        while (reader.next()) switch (reader.type) with (INIToken) {
            case SECTION:
                section = &this;
                string name = reader.value.get!string;
                auto parts = name.split(":");

                // [section : parent]
                if (parts.length > 1)
                    name = parts[0].strip;

                IniSection child = IniSection(name, section);

                if (parts.length > 1) {
                    string parent = parts[1].strip;
                    child.inherit(section.getSectionEx(parent));
                }
                section.addSection(child);
                section = &section.getSection(name);
                break;

            case KEY:
                section.setKey(reader.value.get!KeyType.name, reader.value.get!KeyType.value);
                break;

            default:
                break;
        }

        if(doLookups == true)
            parseLookups();
    }
    
    /**
     * Parses lookups
     */
    public void parseLookups()
    {
        foreach (name, ref value; _keys)
        {
            ptrdiff_t start = -1;
            char[] buf;
            
            foreach (i, c; value) {
                if (c == '%') {
                    if (start != -1) {
                        IniSection sect;
                        string newValue;
                        char[][] parts;
                        
                        if (buf[0] == '.') {
                            parts = buf[1..$].split(".");
                            sect = this.root;
                        }
                        else {
                            parts = buf.split(".");
                            sect = this;
                        }
                        
                        newValue = sect.getSectionEx(parts[0..$-1].join(".").idup).getKey(parts[$-1].idup);
                        value.replaceInPlace(start, i+1, newValue);
                        start = -1;
                        buf = [];
                    }
                    else {
                        start = i;
                    }
                }
                else if (start != -1) {
                    buf ~= c;
                }
            }
        }
        
        foreach(child; _sections) {
            child.parseLookups();
        }
    }
    
    /**
     * Returns section by name in inheriting(names connected by dot)
     *
     * Params:
     *  name = Section name
     *
     * Returns:
     *  Section
     */
    public IniSection getSectionEx(string name)
    {
        IniSection* root = &this;
        auto parts = name.split(".");
        
        foreach(part; parts) {
            root = (&root.getSection(part));
        }
        
        return *root;
    }
    
    /**
     * Inherits keys from section
     *
     * Params:
     *  Section to inherit
     */
    public void inherit(IniSection sect)
    {
        foreach (key; sect._keys.keys) {
            this._keys[key] = sect._keys[key].dup;
        }
    }

    public void save(string filename)
    {
        import std.file;

        if (exists(filename))
            remove(filename);

        File file = File(filename, "w");

        foreach (section; _sections) {
            file.writeln("[" ~ section.name() ~ "]");

            string[string] propertiesInSection = section.keys();
            foreach (key; propertiesInSection.keys) {
                file.writeln(key ~ " = " ~ propertiesInSection[key]);
            }

            file.writeln();
        }

        file.close();
    }


    /**
     * Parses Ini file
     *
     * Params:
     *  filename = Path to ini file
     *
     * Returns:
     *  IniSection root
     */
    static Ini Parse(string filename, bool parseLookups = true)
    {
        Ini i;
        i.parse(filename, parseLookups);
        return i;
    }


    /**
     * Parses Ini file with specified reader
     *
     * Params:
     *  filename = Path to ini file
     *
     * Returns:
     *  IniSection root
     */
    static Ini ParseWith(Reader)(string filename, bool parseLookups = true)
    {
        Ini i;
        i.parseWith!Reader(filename, parseLookups);
        return i;
    }

    static Ini ParseString(string data, bool parseLookups = true)
    {
        Ini i;
        i.parseString(data, parseLookups);
        return i;
    }

    static Ini ParseStringWith(Reader)(string data, bool parseLookups = true)
    {
        Ini i;
        i.parseStringWith!Reader(data, parseLookups);
        return i;
    }
}

// Compat
alias INIException IniException;

/// ditto
alias IniSection Ini;


///
Struct siphon(Struct)(Ini ini)
{
	import std.traits;
	Struct ans;
	if(ini.hasSection(Struct.stringof))
		foreach(ti, Name; FieldNameTuple!(Struct))
		{
			alias ToType = typeof(ans.tupleof[ti]);
			if(ini[Struct.stringof].hasKey(Name))
				ans.tupleof[ti] = to!ToType(ini[Struct.stringof].getKey(Name));
		}
	return ans;
}

unittest {
	struct Section {
		int var;
	}

	auto ini = Ini.ParseString("[Section]\nvar=3");
	auto m = ini.siphon!Section;
	assert(m.var == 3);
}


unittest {
    auto data = q"(
key1 = value

# comment

test = bar ; comment

[section 1]
key1 = new key
num = 151
empty


[ various   ]
"quoted key"= VALUE 123

quote_multiline = """
  this is value
"""

escape_sequences = "yay\nboo"
escaped_newlines = abcd \
efg
)";

    auto ini = Ini.ParseString(data);
    assert(ini.getKey("key1") == "value");
    assert(ini.getKey("test") == "bar ; comment");

    assert(ini.hasSection("section 1"));
    with (ini["section 1"]) {
        assert(getKey("key1") == "new key");
        assert(getKey("num") == "151");
        assert(getKey("empty") == "");
    }

    assert(ini.hasSection("various"));
    with (ini["various"]) {
        assert(getKey("quoted key") == "VALUE 123");
        assert(getKey("quote_multiline") == "\n  this is value\n");
        assert(getKey("escape_sequences") == "yay\nboo");
        assert(getKey("escaped_newlines") == "abcd efg");
    }
}

unittest {
    auto data = q"EOF
key1 = value

# comment

test = bar ; comment

[section 1]
key1 = new key
num = 151
empty

EOF";

    auto ini = Ini.ParseString(data);
    assert(ini.getKey("key1") == "value");
    assert(ini.getKey("test") == "bar ; comment");
    assert(ini.hasSection("section 1"));
    assert(ini["section 1"]("key1") == "new key");
    assert(ini["section 1"]("num") == "151");
    assert(ini["section 1"]("empty") == "");
}

unittest {
	auto data = q"EOF
[def]
name1=value1
name2=value2

[foo : def]
name1=Name1 from foo. Lookup for def.name2: %name2%
EOF";

    // Parse file
    auto ini = Ini.ParseString(data, true);

    assert(ini["foo"].getKey("name1")
	  == "Name1 from foo. Lookup for def.name2: value2");
}

unittest {
	auto data = q"EOF
[section]
name=%value%
EOF";

	// Create ini struct instance
	Ini ini;
	Ini iniSec = IniSection("section");
	ini.addSection(iniSec);

	// Set key value
	ini["section"].setKey("value", "verify");

	// Now, you can use value in ini file
	ini.parseString(data);

	assert(ini["section"].getKey("name") == "verify");
}


unittest {
    import dini.reader;

    alias MyReader = INIReader!(
        UniversalINIFormat,
        UniversalINIReader.CurrentFlags & ~INIFlags.ProcessEscapes,
        UniversalINIReader.CurrentBoxer
    );
    auto ini = Ini.ParseStringWith!MyReader(`path=C:\Path`);
    assert(ini("path") == `C:\Path`);
}