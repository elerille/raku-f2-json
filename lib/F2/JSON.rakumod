class F2::JSON is export(:import) {

    grammar Grammar {
        rule TOP {
            <.ws> <value>
        }
        proto token value {*}
        rule value:type<object> {
            '{' ~ '}' <pair> * % ','
        }
        rule value:type<array> {
            '[' ~ ']' <value> * % ','
        }
        token value:type<number> {
            '-'?
            ['0' | <[1..9]> <[0..9]>*]
            ['.' <[0..9]>+]?
            [<[eE]> <[+-]>? <[0..9]>+]?
        }
        token value:type<true> { "true" }
        token value:type<false> { "false" }
        token value:type<null> { "null" }
        token value:type<string> {
            # see https://github.com/moritz/json/issues/25
            (:ignoremark '"') ~ '"' <chars>*
        }

        rule pair {
            <key=.value:type<string>> ':' <value>
        }

        proto token chars {*}
        token chars:type<literal> { <-["\\]>+ }
        token chars:type<escaped> {
            '\\' <( <["\\/]> )>
        }
        token chars:type<backspace> { '\\b' }
        token chars:type<formfeed> { '\\f' }
        token chars:type<linefeed> { '\\n' }
        token chars:type<carriage-return> { '\\r' }
        token chars:type<horizontal-tab> { '\\t' }
        token chars:type<unicode> { <unicode>+ }
        token unicode {
            '\\u' <( <xdigit> ** 4 )>
        }

        token ws { <[\x[20] \xA \xD \xD \x9 \n]>* }

    }
    class Actions {
        has Bool:D $.allow-multiple-key = False;
        method TOP($/) {
            make $<value>.made
        }
        method value:type<object>($/) {
            given $<pair>».made {
                if $!allow-multiple-key { make $_ }
                else { make $_.hash }
            }
        }
        method value:type<array>($/) {
            make $<value>».made;
        }
        method value:type<number>($/) {
            make +$/
        }
        method value:type<true>($/) {
            make True
        }
        method value:type<false>($/) {
            make False
        }
        method value:type<null>($/) {
            make Nil
        }
        method value:type<string>($/) {
            my $str = $/<chars>».made.join;

            # see https://github.com/moritz/json/issues/25
            if $0.Str ne '"' {
                $str = $0.Str.NFC[1 ..*].chrs ~ $str;
            }
            make $str;
        }

        method chars:type<literal>($/) {
            make ~$/
        }
        method chars:type<escaped>($/) {
            make ~$/
        }
        method chars:type<backspace>($/) {
            make "\b"
        }
        method chars:type<formfeed>($/) {
            make "\f"
        }
        method chars:type<linefeed>($/) {
            make "\n"
        }
        method chars:type<carriage-return>($/) {
            make "\r"
        }
        method chars:type<horizontal-tab>($/) {
            make "\t"
        }
        method chars:type<unicode>($/) {
            make utf16.new($<unicode>.map({ :16(~$_) })).decode;
        }

        method pair($/) {
            make Pair.new: $<key>.made, $<value>.made;
        }

    }

    multi method parse(F2::JSON:U: Str:D $data) {
        with Grammar.parse($data, actions => Actions.new(|%_)) { .made }
        else { fail }
    }
    multi method parsefile(F2::JSON:U: $data) {
        with Grammar.parsefile($data, actions => Actions.new(|%_)) { .made }
        else { fail }
    }
    multi method to-str(F2::JSON:U: $data is raw) {
        my $out = $*OUT;
        $*OUT = class {
            also is IO::Handle;
            has @.data = [];
            submethod TWEAK {
                self.encoding: 'utf8'
            }
            method WRITE(IO::Handle:D: Blob:D \data --> Bool:D) {
                @!data.push: data.decode();
                True;
            }
            method gist() {
                @!data.join
            }
        }.new;
        self.__serialize($data);
        my $output = $*OUT.gist;
        $*OUT = $out;
        return $output;

    }
    multi method __serialize(F2::JSON:U: Bool:D $_) {
        print $_ ?? 'true' !! 'false'
    }
    multi method __serialize(F2::JSON:U: Any:U $_) {
        print 'null'
    }
    multi method __serialize(F2::JSON:U: Int:D $_) {
        print .Str
    }
    multi method __serialize(F2::JSON:U: Num:D $_) {
        print .Str;
        unless .Str.contains('.') {
            print '.0'
        }
    }
    multi method __serialize(F2::JSON:U: Rational:D $_) {
        print .Str;
        unless .Str.contains('.') {
            print '.0'
        }
    }
    multi method __serialize(F2::JSON:U: Str:D $_) {
        print '"';
        print .comb.map({
            when '"' { '\\"' }
            when '\\' { '\\\\' }
            when "\b" { '\\b' }
            when "\f" { '\\f' }
            when "\n" { '\\n' }
            when "\r" { '\\r' }
            when "\t" { '\\t' }
            default { $_ }
        }).join;
        print '"';
    }
    multi method __serialize(F2::JSON:U: Positional:D $_) {
        print '[';
        my $sep = False;
        for @$_ {
            if $sep { print ',' }
            else { $sep = True }
            self.__serialize($_);
        }
        print ']';
    }
    multi method __serialize(F2::JSON:U: Associative:D $_) {
        print '{';
        my $sep = False;
        for @$_ {
            if $sep { print ',' }
            else { $sep = True }
            self.__serialize(.key);
            print ':';
            self.__serialize(.value);
        }
        print '}';
    }

}
