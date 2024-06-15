package StartClient;
# use warnings;
# use strict;
my $pppid = '';

# NOTE: there's no reason to create an object, we can just access
# the features statically. 
# args: none
# sub new {
# 	my $class = shift;
# 	my $self = {};
# 	# print "$f\n";
# 	# print "$type\n";
# 	return bless $self, $class;
# }

sub set {
	eval $start if $b_log;
	# $b_irc = 1; # for testing, like cli konvi start which shows as tty
	if (!$b_irc){
		# we'll run ShellData::set() for -I, but only then
	}
	else {
		$use{'filter'} = 1; 
		PsData::set() if !$loaded{'ps-data'};
		get_client_name();
		if ($client{'konvi'} == 1 || $client{'konvi'} == 3){
			set_konvi_data();
		}
	}
	eval $end if $b_log;
}

sub get_client_name {
	eval $start if $b_log;
	my $client_name = '';
	# print "$ppid\n";
	if ($ppid && -e "/proc/$ppid/exe"){
		$client_name = lc(readlink "/proc/$ppid/exe");
		$client_name =~ s/^.*\///;
		if ($client_name =~ /^(bash|csh|dash|fish|sh|python.*|perl.*|zsh)$/){
			$pppid = (main::grabber("ps -wwp $ppid -o ppid 2>/dev/null"))[1];
			# my @temp = (main::grabber("ps -wwp $ppid -o ppid 2>/dev/null"))[1];
			$pppid =~ s/^\s+|\s+$//g;
			$client_name =~ s/[0-9\.]+$//; # clean things like python2.7
			if ($pppid && -f "/proc/$pppid/exe"){
				$client_name = lc(readlink "/proc/$pppid/exe");
				$client_name =~ s/^.*\///;
				$client{'native'} = 0;
			}
		}
		$client{'name'} = $client_name;
		get_client_version();
		# print "c:$client_name p:$pppid\n";
		# print "$client{'name-print'}\n";
	}
	else {
		if (!check_modern_konvi()){
			$client_name = (main::grabber("ps -wwp $ppid 2>/dev/null"))[1];
			if ($client_name){
				my @data = split(/\s+/, $client_name);
				if ($bsd_type){
					$client_name = lc($data[4]);
				}
				# gnu/linux uses last value
				else {
					$client_name = lc($data[-1]);
				}
				$client_name =~ s/.*\|-(|)//;
				$client_name =~ s/[0-9\.]+$//; # clean things like python2.7
				$client{'name'} = $client_name;
				$client{'native'} = 1;
				get_client_version();
			}
			else {
				$client{'name'} = "PPID='$ppid' - Empty?";
			}
		}
	}
	if ($b_log){
		my $string = "Client: $client{'name'} :: version: $client{'version'} ::";
		$string .= " konvi: $client{'konvi'} :: PPID: $ppid";
		main::log_data('data', $string);
	}
	eval $end if $b_log;
}

sub get_client_version {
	eval $start if $b_log;
	my @app = ProgramData::values($client{'name'});
	my (@data,@working,$string);
	if (@app){
		$string = ($client{'name'} =~ /^gribble|limnoria|supybot$/) ? 'supybot' : $client{'name'};
		$client{'version'} = ProgramData::version($string,$app[0],$app[1],$app[2],$app[4],$app[5],$app[6]);
		$client{'name-print'} = $app[3];
		$client{'console-irc'} = $app[4];
	}
	if ($client{'name'} =~ /^(bash|csh|fish|dash|sh|zsh)$/){
		$client{'name-print'} = 'shell wrapper';
		$client{'console-irc'} = 1;
	}
	elsif ($client{'name'} eq 'bitchx'){
		@data = main::grabber("$client{'name'} -v 2>/dev/null");
		$string = awk(\@data,'Version');
		if ($string){
			$string =~ s/[()]|bitchx-//g; 
			@data = split(/\s+/, $string);
			$_=lc for @data;
			$client{'version'} = ($data[1] eq 'version') ? $data[2] : $data[1];
		}
	}
	# 'hexchat' => ['',0,'','HexChat',0,0], # special
	# the hexchat author decided to make --version/-v return a gtk dialogue box, lol...
	# so we need to read the actual config file for hexchat. Note that older hexchats
	# used xchat config file, so test first for default, then legacy. Because it's possible
	# for this file to be user edited, doing some extra checks here.
	elsif ($client{'name'} eq 'hexchat'){
		if (-f '~/.config/hexchat/hexchat.conf'){
			@data = main::reader('~/.config/hexchat/hexchat.conf','strip');
		}
		elsif (-f '~/.config/hexchat/xchat.conf'){
			@data = main::reader('~/.config/hexchat/xchat.conf','strip');
		}
		if (@data){
			$client{'version'} = main::awk(\@data,'version',2,'\s*=\s*');
		}
		# fingers crossed, hexchat won't open gui!!
		if (!$client{'version'}){
			@data = main::grabber("$client{'name'} --version 2>/dev/null");
			$client{'version'} = main::awk(\@data,'hexchat',2,'\s+');
		}
		$client{'name-print'} = 'HexChat';
	}
	# note: see legacy inxi konvi logic if we need to restore any of the legacy code.
	elsif ($client{'name'} eq 'konversation'){
		$client{'konvi'} = (!$client{'native'}) ? 2 : 1;
	}
	elsif ($client{'name'} =~ /quassel/i){
		@data = main::grabber("$client{'name'} -v 2>/dev/null");
		foreach (@data){
			if ($_ =~ /^Quassel IRC:/){
				$client{'version'} = (split(/\s+/, $_))[2];
				last;
			}
			elsif ($_ =~ /quassel\s[v]?[0-9]/){
				$client{'version'} = (split(/\s+/, $_))[1];
				last;
			}
		}
		$client{'version'} ||= '(pre v0.4.1)?'; 
	}
	# then do some perl type searches, do this last since it's a wildcard search
	elsif ($client{'name'} =~ /^(perl.*|ksirc|dsirc)$/){
		my $cmdline = main::get_cmdline();
		# Dynamic runpath detection is too complex with KSirc, because KSirc is started from
		# kdeinit. /proc/<pid of the grandparent of this process>/exe is a link to /usr/bin/kdeinit
		# with one parameter which contains parameters separated by spaces(??), first param being KSirc.
		# Then, KSirc runs dsirc as the perl irc script and wraps around it. When /exec is executed,
		# dsirc is the program that runs inxi, therefore that is the parent process that we see.
		# You can imagine how hosed I am if I try to make inxi find out dynamically with which path
		# KSirc was run by browsing up the process tree in /proc. That alone is straightjacket material.
		# (KSirc sucks anyway ;)
		foreach (@$cmdline){
			if ($_ =~ /dsirc/){
				$client{'name'} = 'ksirc';
				($client{'name-print'},$client{'version'}) = ProgramData::full('ksirc');
			}
		}
		$client{'console-irc'} = 1;
		perl_python_client();
	}
	elsif ($client{'name'} =~ /python/){
		perl_python_client();
	}
	# NOTE: these must be empirically determined, not all events that 
	# show no tty are actually IRC. tmux is not a vt, but runs inside one
	if (!$client{'name-print'}){
		my $wl_terms = 'alacritty|altyo|\bate\b|black-screen|conhost|doas|evilvte|';
		$wl_terms .= 'foot|germinal|guake|havoc|hyper|kate|kitty|kmscon|konsole|';
		$wl_terms .= 'login|macwise|minicom|putty|rxvt|sakura|securecrt|';
		$wl_terms .= 'shellinabox|^st$|sudo|term|tilda|tilix|tmux|tym|wayst|xiki|';
		$wl_terms .= 'yaft|yakuake|\bzoc\b';
		my $wl_clients = 'ansible|chef|run-parts|slurm|sshd';
		my $whitelist = "$wl_terms|$wl_clients";
		# print "$client{'name'}\n";
		if ($client{'name'} =~ /($whitelist)/i){
			if ($client{'name'} =~ /($wl_terms)/i){
				ShellData::set();
			}
			else {
				$client{'name-print'} = $client{'name'};
			}
			$b_irc = 0;
			$use{'filter'} = 0; 
		}
		else {
			$client{'name-print'} = 'Unknown Client: ' . $client{'name'};
		}
	}
	eval $end if $b_log;
}

sub get_cmdline {
	eval $start if $b_log;
	my @cmdline;
	my $i = 0;
	if (! -e "/proc/$ppid/cmdline"){
		return 1;
	}
	local $\ = '';
	open(my $fh, '<', "/proc/$ppid/cmdline") or 
		print_line("Open /proc/$ppid/cmdline failed: $!");
	my @rows = <$fh>;
	close $fh;
	foreach (@rows){
		push(@cmdline, $_);
		$i++;
		last if $i > 31;
	}
	if ($i == 0){
		$cmdline[0] = $rows[0];
		$i = ($cmdline[0]) ? 1 : 0;
	}
	main::log_data('string',"cmdline: @cmdline count: $i") if $b_log;
	eval $end if $b_log;
	return [@cmdline];
}

sub perl_python_client {
	eval $start if $b_log;
	return 1 if $client{'version'};
	my @app;
	# this is a hack to try to show konversation if inxi is running but started via /cmd
	# OR via program shortcuts, both cases in fact now
	# main::print_line("konvi: " . scalar grep { $_ =~ /konversation/ } @ps_cmd);
	if ($b_display && main::check_program('konversation') && 
	 (grep { $_ =~ /konversation/ } @ps_cmd)){
		@app = ProgramData::values('konversation');
		$client{'version'} = ProgramData::version('konversation',$app[0],$app[1],$app[2],$app[5],$app[6]);
		$client{'name'} = 'konversation';
		$client{'name-print'} = $app[3];
		$client{'console-irc'} = $app[4];
	}
	## NOTE: supybot only appears in ps aux using 'SHELL' command; the 'CALL' command
	## gives the user system irc priority, and you don't see supybot listed, so use SHELL
	elsif (!$b_display && 
	 (main::check_program('supybot') || 
	 main::check_program('gribble') || main::check_program('limnoria')) &&
	 (grep { $_ =~ /supybot/ } @ps_cmd)){
		@app = ProgramData::values('supybot');
		$client{'version'} = ProgramData::version('supybot',$app[0],$app[1],$app[2],$app[5],$app[6]);
		if ($client{'version'}){
			if (grep { $_ =~ /gribble/ } @ps_cmd){
				$client{'name'} = 'gribble';
				$client{'name-print'} = 'Gribble';
			}
			if (grep { $_ =~ /limnoria/ } @ps_cmd){
				$client{'name'} = 'limnoria';
				$client{'name-print'} = 'Limnoria';
			}
			else {
				$client{'name'} = 'supybot';
				$client{'name-print'} = 'Supybot';
			}
		}
		else {
			$client{'name'} = 'supybot';
			$client{'name-print'} = 'Supybot';
		}
		$client{'console-irc'} = 1;
	}
	else {
		$client{'name-print'} = "Unknown $client{'name'} client";
	}
	if ($b_log){
		my $string = "namep: $client{'name-print'} name: $client{'name'} ";
		$string .= " version: $client{'version'}";
		main::log_data('data',$string);
	}
	eval $end if $b_log;
}

# Try to infer the use of Konversation >= 1.2, which shows $PPID improperly
# no known method of finding Konvi >= 1.2 as parent process, so we look to 
# see if it is running, and all other irc clients are not running. As of 
# 2014-03-25 this isn't used in my cases
sub check_modern_konvi {
	eval $start if $b_log;
	return 0 if !$client{'qdbus'};
	my ($b_modern_konvi,$konvi,$konvi_version,$pid) = (0,'','','');
	# main::log_data('data',"name: $client{'name'} :: qdb: $client{'qdbus'} :: version: $client{'version'} :: konvi: $client{'konvi'} :: PPID: $ppid") if $b_log;
	# sabayon uses /usr/share/apps/konversation as path
	# Paths not checked for BSDs to see what they are.
	if (-d '/usr/share/kde4/apps/konversation' || -d '/usr/share/apps/konversation'){
		# much faster test, added 2022, newer konvis support
		# can also query qdbus to see if it's running, but that's a subshell and grep
		if ($ENV{'PYTHONPATH'} && $ENV{'PYTHONPATH'} =~ /konversation/i){
			$konvi = 'konversation';
		}
		# was -session, then -qwindowtitle; cli start, nothing, just konversation$
		elsif ($pid = main::awk(\@ps_aux,'konversation( -|$)',2,'\s+')){
			main::log_data('data',"pid: $pid") if $b_log;
			if (-e "/proc/$pid/exe"){
				$konvi = readlink("/proc/$pid/exe");
				$konvi =~ s/^.*\///; # basename
			}
		}
		# print "$pid $konvi\n";
		if ($konvi){
			my @app = ProgramData::values('konversation');
			$konvi_version = ProgramData::version($konvi,$app[0],$app[1],$app[2],$app[5],$app[6]);
			$client{'console-irc'} = $app[4];
			$client{'konvi'} = 3;
			$client{'name'} = 'konversation';
			$client{'name-print'} = $app[3];
			$client{'version'} = $konvi_version;
			# note: we need to change this back to a single dot number, like 1.3, not 1.3.2
			my @temp = split('\.', $konvi_version);
			$konvi_version = $temp[0] . "." . $temp[1];
			if ($konvi_version > 1.1){
				$b_modern_konvi = 1;
			}
		}
	}
	main::log_data('data',"name: $client{'name'} name print: $client{'name-print'} 
	qdb: $client{'qdbus'} version: $konvi_version konvi: $konvi PID: $pid") if $b_log;
	main::log_data('data',"b_is_qt4: $b_modern_konvi") if $b_log;
	## for testing this module
	# my $ppid = getppid();
	# system('qdbus org.kde.konversation', '/irc', 'say', $client{'dserver'}, $client{'dtarget'}, 
	# "getpid_dir: verNum: $konvi_version pid: $pid ppid: $ppid");
	# print "verNum: $konvi_version pid: $pid ppid: $ppid\n";
	eval $end if $b_log;
	return $b_modern_konvi;
}

sub set_konvi_data {
	eval $start if $b_log;
	# https://userbase.kde.org/Konversation/Scripts/Scripting_guide
	if ($client{'konvi'} == 3){
		$client{'dserver'} = shift @ARGV;
		$client{'dtarget'} = shift @ARGV;
		$client{'dobject'} = 'default';
	}
	elsif ($client{'konvi'} == 1){
		$client{'dport'} = shift @ARGV;
		$client{'dserver'} = shift @ARGV;
		$client{'dtarget'} = shift @ARGV;
		$client{'dobject'} = 'Konversation';
	}
	# for some reason this logic hiccups on multiple spaces between args
	@ARGV = grep { $_ ne '' } @ARGV;
	eval $end if $b_log;
}
}

########################################################################
#### OUTPUT
########################################################################

#### -------------------------------------------------------------------
#### CLEANERS, FILTERS, AND TOOLS
#### -------------------------------------------------------------------

sub clean {
	my ($item) = @_;
	return $item if !$item;# handle cases where it was 0 or '' or undefined
	# note: |nee trips engineering, but I don't know why nee was filtered
	$item =~ s/chipset|company|components|computing|computer|corporation|communications|electronics?|electric(al)?|group|incorporation|industrial|international|limited|\bnee\b|<?no\sstring>?|revision|semiconductor|software|technolog(ies|y)|<?unknown>?|ltd\.|<ltd>|\bltd\b|inc\.|<inc>|\binc\b|intl\.|co\.|<co>|corp\.|<corp>|\(tm\)|\(r\)|®|\(rev ..\)|\'|\"|\?//gi;
	$item =~ s/,|\*/ /g;
	$item =~ s/^\s+|\s+$//g;
	$item =~ s/\s\s+/ /g;
	return $item;
}

sub clean_arm {
	my ($item) = @_;
	$item =~ s/(\([^\(]*Device Tree[^\)]*\))//gi;
	$item =~ s/^\s+|\s+$//g;
	$item =~ s/\s\s+/ /g;
	return $item;
}

sub clean_characters {
	my ($data) = @_;
	# newline, pipe, brackets, + sign, with space, then clear doubled
	# spaces and then strip out trailing/leading spaces.
	# etc/issue often has junk stuff like (\l)  \n \l
	return if !$data;
	$data =~ s/[:\47]|\\[a-z]|\n|,|\"|\*|\||\+|\[\s\]|n\/a|\s\s+/ /g; 
	$data =~ s/\(\s*\)//;
	$data =~ s/^\s+|\s+$//g;
	return $data;
}

sub clean_disk {
	my ($item) = @_;
	return $item if !$item;
	# <?unknown>?|
	$item =~ s/vendor.*|product.*|O\.?E\.?M\.?//gi;
	$item =~ s/^\s+|\s+$//g;
	$item =~ s/\s\s+/ /g;
	return $item;
}

sub clean_dmi {
	my ($string) = @_;
	$string = clean_unset($string,'AssetTagNum|^Base Board .*|^Chassis .*|' .
	'Manufacturer.*| Or Motherboard|\bOther\b.*|PartNum.*|SerNum|' .
	'^System .*|^0x[0]+$');
	$string =~ s/\bbios\b|\bacpi\b//gi;
	$string =~ s/http:\/\/www.abit.com.tw\//Abit/i;
	$string =~ s/^[\s'"]+|[\s'"]+$//g;
	$string =~ s/\s\s+/ /g;
	$string = remove_duplicates($string) if $string;
	return $string;
}

sub clean_pci {
	my ($string,$type) = @_;
	# print "st1 $type:$string\n";
	my $filter = 'and\ssubsidiaries|compatible\scontroller|licensed\sby|';
	$filter .= '\b(device|controller|connection|multimedia)\b|\([^)]+\)';
	# \[[^\]]+\]$| not trimming off ending [...] initial type filters removes end
	$filter = '\[[^\]]+\]$|' . $filter if $type eq 'pci';
	$string =~ s/($filter)//ig;
	$string =~ s/^[\s'"]+|[\s'"]+$//g;
	$string =~ s/\s\s+/ /g;
	# print "st2 $type:$string\n";
	$string = remove_duplicates($string) if $string;
	return $string;
}

sub clean_pci_subsystem {
	my ($string) = @_;
	# we only need filters for features that might use vendor, -AGN
	my $filter = 'and\ssubsidiaries|adapter|(hd\s)?audio|definition|desktop|ethernet|';
	$filter .= 'gigabit|graphics|hdmi(\/[\S]+)?|high|integrated|licensed\sby|';
	$filter .= 'motherboard|network|onboard|raid|pci\s?express';
	$string =~ s/\b($filter)\b//ig;
	$string =~ s/^[\s'"]+|[\s'"]+$//g;
	$string =~ s/\s\s+/ /g;
	return $string;
}

# Use sparingly, but when we need regex type stuff 
# stripped out for reliable string compares, it's better.
# sometimes the pattern comes from unknown strings 
# which can contain regex characters, get rid of those
sub clean_regex {
	my ($string) = @_;
	return if !$string;
	$string =~ s/(\{|\}|\(|\)|\[|\]|\|)/ /g;
	$string =~ s/^\s+|\s+$//g;
	$string =~ s/\s\s+/ /g;
	return $string;
}

# args: 0: string; 1: optional, if you want to add custom filter to defaults
sub clean_unset {
	my ($string,$extra) = @_;
	my $cleaner = '^(\.)+$|Bad Index|default string|\[?empty\]?|\bnone\b|N\/A|^not |';
	$cleaner .= 'not set|OUT OF SPEC|To be filled|O\.?E\.?M|undefine|unknow|unspecif';
	$cleaner .= '|' . $extra if $extra;
	$string =~ s/.*($cleaner).*//i;
	return $string;
}

sub filter {
	my ($string,$type) = @_;
	if ($string){
		$type ||= 'filter';
		if ($use{$type} && $string ne message('root-required')){
			$string = $filter_string;
		}
	}
	else {
		$string = 'N/A';
	}
	return $string;
}

# Note, let the print logic handle N/A cases
sub filter_partition {
	my ($source,$string,$type) = @_;
	return $string if !$string || $string eq 'N/A';
	if ($source eq 'system'){
		my $test = ($type eq 'label') ? '=LABEL=': '=UUID=';
		$string =~ s/$test[^\s]+/$test$filter_string/g;
	}
	else {
		$string = $filter_string;
	}
	return $string;
}

sub filter_pci_long {
	my ($string) = @_;
	if ($string =~ /\[AMD(\/ATI)?\]/){
		$string =~ s/Advanced\sMicro\sDevices\s\[AMD(\/ATI)?\]/AMD/;
	}
	return $string;
}

# args: 0: list of values. Return the first one that is defined.
sub get_defined {
	for (@_){
		return $_ if defined $_;
	}
	return; # don't return undef explicitly, only implicitly!
}

# args: 0: vendor id; 1: product id.
# Returns print ready vendor:chip id string, or na variants
sub get_chip_id {
	my ($vendor,$product)= @_;
	my $id = 'N/A';
	if ($vendor && $product){
		$id = "$vendor:$product";
	}
	elsif ($vendor){
		$id = "$vendor:n/a";
	}
	elsif ($product){
		$id = "n/a:$product";
	}
	return $id;
}

# args: 0: size in KiB, return KiB, MiB, GiB, TiB, PiB, EiB; 1: 'string';
# 2: default value if null. Assumes KiB input.
# Returns string with units or array or size unmodified if not numeric
sub get_size {
	my ($size,$type,$empty) = @_;
	my (@data);
	$type ||= '';
	$empty ||= '';
	return $empty if !defined $size;
	if (!is_numeric($size)){
		$data[0] = $size;
		$data[1] = '';
	}
	elsif ($size > 1024**5){
		$data[0] = sprintf("%.2f",$size/1024**5);
		$data[1] = 'EiB';
	}
	elsif ($size > 1024**4){
		$data[0] = sprintf("%.2f",$size/1024**4);
		$data[1] = 'PiB';
	}
	elsif ($size > 1024**3){
		$data[0] = sprintf("%.2f",$size/1024**3);
		$data[1] = 'TiB';
	}
	elsif ($size > 1024**2){
		$data[0] = sprintf("%.2f",$size/1024**2);
		$data[1] = 'GiB';
	}
	elsif ($size > 1024){
		$data[0] = sprintf("%.1f",$size/1024);
		$data[1] = 'MiB';
	}
	else {
		$data[0] = sprintf("%.0f",$size);
		$data[1] = 'KiB';
	}
	$data[0] += 0 if $data[1]; # trim trailing 0s
	# note: perl throws strict error if you try to convert string to int
	# $data[0] = int($data[0]) if $b_int && $data[0];
	if ($type eq 'string'){
		return ($data[1]) ? join(' ', @data) : $size;
	}
	else {
		return @data;
	}
}

# not used, but keeping logic for now
sub increment_starters {
	my ($key,$indexes) = @_;
	my $result = $key;
	if (defined $indexes->{$key}){
		$indexes->{$key}++;
		$result = "$key-$indexes->{$key}";
	}
	return $result;
}

sub make_line {
	my $line = '';
	foreach (0 .. $size{'max-cols-basic'} - 2){
		$line .= '-';
	}
	return $line;
}

# Takes an array ref, creates value ref, comma separated, with ','/', ' 
# depending on assigned max list value length.
# args: 0: array ref; 1: value result ref; 2: [separator]; 3: [sort];
# 4: [N/A value, if missing, return undef]
sub make_list_value {
	my $sep = $_[2];
	$sep ||= ',';
	if (!defined $_[0] || !@{$_[0]}){
		${$_[1]} = $_[4] if $_[4];
		return;
	}
	# note: printer only wraps if value 'word' count > 2, and trick with quoting
	# array includes 1 white space between values
	if (scalar @{$_[0]} > 2 && length("@{$_[0]}") > $size{'max-join-list'}){
		$sep .= ' ';
	}
	@{$_[0]} = sort {"\L$a" cmp "\L$b"} @{$_[0]} if $_[3] && $_[3] eq 'sort';
	${$_[1]} = join($sep,@{$_[0]});
}

# args: 0: type; 1: info [optional]; 2: info [optional]
sub message {
	my ($type,$id,$id2) = @_;
	$id ||= '';
	$id2 ||= '';
	my %message = (
	'arm-cpu-f' => 'Use -f option to see features',
	'audio-server-on-pipewire-pulse' => 'off (using pipewire-pulse)',
	'audio-server-process-on' => 'active (process)',
	'audio-server-root-na' => 'n/a (root, process)',
	'audio-server-root-on' => 'active (root, process)',
	'battery-data' => 'No system battery data found. Is one present?',
	'battery-data-bsd' => 'No battery data found. Try with --dmidecode',
	'battery-data-sys' => 'No /sys data found.',
	'bluetooth-data' => 'No bluetooth data found.',
	'bluetooth-down' => "tool can't run",
	'cpu-bugs-null' => 'No CPU vulnerability/bugs data available.',
	'cpu-model-null' => 'Model N/A',
	'cpu-speeds' => 'No per core speed data found.',
	'cpu-speeds-bsd' => 'No OS support for core speeds.',
	'darwin-feature' => 'Feature not supported iu Darwin/OSX.',
	'dev' => 'Feature under development',
	'device-data' => 'No device data found.',
	'disk-data' => 'No disk data found.',
	'disk-data-bsd' => 'No disk data found.',
	'disk-size-0' => 'Total N/A',
	'display-driver-na' => 'X driver n/a', # legacy, leave for now
	'display-driver-na-try-root' => 'X driver n/a, try sudo/root',
	'display-server' => 'No display server data found. Headless machine?',
	'dmesg-boot-permissions' => 'dmesg.boot permissions',
	'dmesg-boot-missing' => 'dmesg.boot not found',
	'dmidecode-dev-mem' => 'dmidecode is not allowed to read /dev/mem',
	'dmidecode-smbios' => 'No SMBIOS data for dmidecode to process',
	'edid-revision' => "invalid EDID revision: $id",
	'edid-sync' => "bad sync value: $id",
	'edid-version' => "invalid EDID version: $id",
	'egl-missing' => 'EGL data requires eglinfo. Check --recommends.',
	'egl-missing-console' => 'EGL data unavailable in console, eglinfo missing.',
	'egl-null' => 'No EGL data available.',
	'file-unreadable' => 'File not readable (permissions?)',
	'gfx-api' => 'No display API data available.',
	'gfx-api-console' => 'No API data available in console. Headless machine?',
	'glx-console-root' => 'GL data unavailable in console for root.',
	'glx-console-try' => 'GL data unavailable in console. Try -G --display',
	'glx-display-root' => 'GL data unavailable for root.',
	'glx-egl' => 'incomplete (EGL sourced)',
	'glx-egl-console' => 'console (EGL sourced)',
	'glx-egl-missing' => 'glxinfo missing (EGL sourced)',
	'glx-missing' => 'Unable to show GL data. glxinfo is missing.',
	'glx-missing-console' => 'GL data unavailable in console, glxinfo missing.',
	'glx-null' => 'No GL data available.',
	'glx-value-empty' => 'Unset. Missing GL driver?',
	'IP' => "No $id found. Connected to web? SSL issues?",
	'IP-dig' => "No $id found. Connected to web? SSL issues? Try --no-dig",
	'IP-no-dig' => "No $id found. Connected to web? SSL issues? Try enabling dig",
	'logical-data' => 'No logical block device data found.',
	'logical-data-bsd' => "Logical block device feature unsupported in $id.",
	'machine-data' => 'No machine data: try newer kernel.',
	'machine-data-bsd' => 'No machine data: Is dmidecode installed? Try -M --dmidecode.',
	'machine-data-dmidecode' => 'No machine data: try newer kernel. Is dmidecode installed? Try -M --dmidecode.',
	'machine-data-force-dmidecode' => 'No machine data: try newer kernel. Is dmidecode installed? Try -M --dmidecode.',
	'machine-data-fruid' => 'No machine data: Is fruid_print installed?',
	'monitor-console' => 'N/A in console',
	'monitor-id' => 'not-matched',
	'monitor-na' => 'N/A',
	'monitor-wayland' => 'no compositor data',
	'network-services' => 'No services found.',
	'note-check' => 'check',
	'note-est' => 'est.',
	'note-not-reliable' => 'not reliable',
	'nv-current' => "current (as of $id)",
	'nv-current-eol' => "current (as of $id; EOL~$id2)",
	'nv-legacy-active' => "legacy-active (EOL~$id)", 
	'nv-legacy-eol' => "legacy (EOL~$id)",
	'optical-data' => 'No optical or floppy data found.',
	'optical-data-bsd' => 'No optical or floppy data found.',
	'output-control' => "-:: 'Enter' to continue to next block. Any key + 'Enter' to exit:",
	'output-control-exit' => 'Exiting output. Have a nice day.',
	'output-limit' => "Output throttled. IPs: $id; Limit: $limit; Override: --limit [1-x;-1 all]",
	'package-data' => 'No packages detected. Unsupported package manager?',
	'partition-data' => 'No partition data found.',
	'partition-hidden' => 'N/A (hidden?)',
	'pci-advanced-data' => 'bus/chip ids n/a',
	'pci-card-data' => 'No PCI device data found.',
	'pci-card-data-root' => 'PCI device data requires root.',
	'pci-slot-data' => 'No PCI Slot data found.',
	'pm-disabled' => "see --$id",
	'ps-data-null' => 'No process data available.',
	'raid-data' => 'No RAID data found.',
	'ram-data' => "No RAM data found using $id.",
	'ram-data-complete' => 'For complete report, try with --dmidecode',
	'ram-data-dmidecode' => 'No RAM data found. Try with --dmidecode',
	'ram-no-module' => 'no module installed',
	'ram-udevadm' => 'For most reliable report, use superuser + dmidecode.',
	'ram-udevadm-root' => 'For most reliable report, install dmidecode.',
	'ram-udevadm-version' => "Installed udevadm v$id. Requires >= 249. Try root?",
	'recommends' => 'see --recommends',
	'repo-data', "No repo data detected. Does $self_name support your package manager?",
	'repo-data-bsd', "No repo data detected. Does $self_name support $id?",
	'risc-pci' => 'No ' . uc($id) . ' data found for this feature.',
	'root-feature' => 'Feature requires superuser permissions.',
	'root-item-incomplete' => "Full $id report requires superuser permissions.",
	'root-required' => '<superuser required>',
	'root-suggested' => 'try sudo/root',# gdm only
	'screen-wayland' => 'no compositor data',
	'screen-tinyx' => "no X$id data",
	'sensor-data-bsd' => "$id sensor data found but not usable.",
	'sensor-data-bsd-ok' => 'No sensor data found. Are data sources present?',
	'sensor-data-bsd-unsupported' => 'Sensor data not available. Unsupported BSD variant.',
	'sensor-data-ipmi' => 'No ipmi sensor data found.',
	'sensor-data-ipmi-root' => 'Unable to run ipmi sensors. Root privileges required.',
	'sensors-data-linux' => 'No sensor data found. Missing /sys/class/hwmon, lm-sensors.',
	'sensor-data-lm-sensors' => 'No sensor data found. Is lm-sensors configured?',
	'sensor-data-sys' => 'No sensor data found in /sys/class/hwmon.',
	'sensor-data-sys-lm' => 'No sensor data found using /sys/class/hwmon or lm-sensors.',
	'smartctl-command' => 'A mandatory SMART command failed. Various possible causes.',
	'smartctl-open' => 'Unable to open device. Wrong device ID given?',
	'smartctl-udma-crc' => 'Bad cable/connection?',
	'smartctl-usb' => 'Unknown USB bridge. Flash drive/Unsupported enclosure?',
	'stopped' => 'stopped',
	'swap-admin' => 'No admin swap data available.',
	'swap-data' => 'No swap data was found.',
	'tool-missing-basic' => "<missing: $id>",
	'tool-missing-incomplete' => "Missing system tool: $id. Output will be incomplete",
	'tool-missing-os' => "No OS support. Is a comparable $id tool available?",
	'tool-missing-recommends' => "Required tool $id not installed. Check --recommends",
	'tool-missing-required' => "Required program $id not available",
	'tool-permissions' => "Unable to run $id. Root privileges required.",
	'tool-present' => 'Present and working',
	'tool-unknown-error' => "Unknown $id error. Unable to generate data.",
	'tools-missing' => "This feature requires one of these tools: $id",
	'tools-missing-bsd' => "This feature requires one of these tools: $id",
	'undefined' => '<undefined>',
	'unmounted-data' => 'No unmounted partitions found.',
	'unmounted-data-bsd' => "Unmounted partition feature unsupported in $id.",
	'unmounted-file' => 'No /proc/partitions file found.',
	'unsupported' => '<unsupported>',
	'usb-data' => 'No USB data found. Server?',
	'usb-mode-mismatch' => '<unknown rev+speed>',
	'unknown-cpu-topology' => 'ERR-103',
	'unknown-desktop-version' => 'ERR-101',
	'unknown-dev' => 'ERR-102',
	'unknown-device-id' => 'unknown device ID',
	'unknown-shell' => 'ERR-100',
	'vulkan-missing' => 'Unable to show Vulkan data. vulkaninfo is missing.', # not used yet
	'vulkan-null' => 'No Vulkan data available.',
	'weather-error' => "Error: $id",
	'weather-null' => "No $id found. Internet connection working?",
	'xvesa-null' => 'No Xvesa VBE/GOP data found.',
	);
	return $message{$type};
}

# args: 0: string of range types (2-5; 3 4; 3,4,2-12) to generate single regex 
# string for
sub regex_range {
	return if ! defined $_[0];
	my @processed;
	foreach my $item (split(/[,\s]+/,$_[0])){
		if ($item =~ /(\d+)-(\d+)/){
			$item = join('|',($1..$2));
		}
		push(@processed,$item);
	}
	return join('|',@processed);
}

# Handles duplicates occuring anywhere in string
sub remove_duplicates {
	my ($string) = @_;
	return if !$string;
	my (%holder,@temp);
	foreach (split(/\s+/, $string)){
		if (!$holder{lc($_)}){
			push(@temp, $_);
			$holder{lc($_)} = 1;
		}
	}
	$string = join(' ', @temp);
	return $string;
}

# args: 0: string to turn to KiB integer value.
# Convert string passed to KB, based on GB/MB/TB id
# NOTE: 1 [K 1000; kB: 1000; KB 1024; KiB 1024] bytes
# The logic will turn false MB to M for this tool
# Hopefully one day sizes will all be in KiB type units
sub translate_size {
	my ($working) = @_;
	my ($size,$unit) = (0,'');
	# print ":$working:\n";
	return if !defined $working;
	my $math = ($working =~ /B$/) ? 1000: 1024;
	if ($working =~ /^([0-9\.]+)\s*([kKMGTPE])i?B?$/i){
		$size = $1;
		$unit = uc($2);
	}
	if ($unit eq 'K'){
		$size = $1;
	}
	elsif ($unit eq 'M'){
		$size = $1 * $math;
	}
	elsif ($unit eq 'G'){
		$size = $1 * $math**2;
	}
	elsif ($unit eq 'T'){
		$size = $1 * $math**3;
	}
	elsif ($unit eq 'P'){
		$size = $1 * $math**4;
	}
	elsif ($unit eq 'E'){
		$size = $1 * $math**5;
	}
	$size = int($size) if $size;
	return $size;
}

#### -------------------------------------------------------------------
#### GENERATE OUTPUT
#### -------------------------------------------------------------------

sub check_output_path {
	my ($path) = @_;
	my ($b_good,$dir,$file);
	$dir = $path;
	$dir =~ s/([^\/]+)$//;
	$file = $1;
	# print "file: $file : dir: $dir\n";
	$b_good = 1 if (-d $dir && -w $dir && $dir =~ /^\// && $file);
	return $b_good;
}

# Passing along hash ref
sub output_handler {
	my ($data) = @_;
	# print Dumper \%data;
	if ($output_type eq 'screen'){
		print_data($data);
	}
	elsif ($output_type eq 'json'){
		generate_json($data);
	}
	elsif ($output_type eq 'xml'){
		generate_xml($data);
	}
}

# Passing along hash ref
# NOTE: file has already been set and directory verified
sub generate_json {
	eval $start if $b_log;
	my ($data) = @_;
	my ($json);
	my $b_debug = 0;
	my ($b_cpanel,$b_valid);
	error_handler('not-in-irc', 'help') if $b_irc;
	print Dumper $data if $b_debug;
	load_json() if !$loaded{'json'};
	print Data::Dumper::Dumper $use{'json'} if $b_debug;
	if ($use{'json'}){
		# ${$use{'json'}->{'new'}}->canonical(1);
		# $json = ${$use{'json'}->{'new'}}->json_encode($data);
		# ${$use{'json'}->{'new-json'}}->canonical(1);
		# $json = ${$use{'json'}->{'new-json'}}->encode_json($data);
		$json = &{$use{'json'}->{'encode'}}($data);
	}
	else {
		error_handler('required-module', 'json', 'JSON::PP, Cpanel::JSON::XS or JSON::XS');
	}
	if ($json){
		#$json =~ s/"[0-9]+#/"/g;
		if ($output_file eq 'print'){
			#$json =~ s/\}/}\n/g;
			print "$json";
		}
		else {
			print_line("Writing JSON data to: $output_file\n");
			open(my $fh, '>', $output_file) or error_handler('open',$output_file,"$!");
			print $fh "$json";
			close $fh;
			print_line("Data written successfully.\n");
		}
	}
	eval $end if $b_log;
}

# NOTE: So far xml is substantially more difficult than json, so 
# using a crude dumper rather than making a nice xml file, but at
# least xml has some output now.
sub generate_xml {
	eval $start if $b_log;
	my ($data) = @_;
	my ($xml);
	my $b_debug = 0;
	error_handler('not-in-irc', 'help') if $b_irc;
	# print Dumper $data if $b_debug;
	if (check_perl_module('XML::Dumper')){
		XML::Dumper->import;
		$xml = XML::Dumper::pl2xml($data);
		#$xml =~ s/"[0-9]+#/"/g;
		if ($output_file eq 'print'){
			print "$xml";
		}
		else {
			print_line("Writing XML data to: $output_file\n");
			open(my $fh, '>', $output_file) or error_handler('open',$output_file,"$!");
			print $fh "$xml";
			close $fh;
			print_line("Data written successfully.\n");
		}
	}
	else {
		error_handler('required-module', 'xml', 'XML::Dumper');
	}
	eval $end if $b_log;
}

sub key {
	return sprintf("%03d#%s#%s#%s", $_[0],$_[1],$_[2],$_[3]);
}

sub output_control {
	print message('output-control');
	chomp(my $response = <STDIN>);
	if (!$response){
		$size{'lines'} = 1;
	}
	else {
		print message('output-control-exit'), "\n";
		exit 0;
	}
}

sub print_basic {
	my ($data) = @_;
	my $indent = 18;
	my $indent_static = 18;
	my $indent1_static = 5;
	my $indent2_static = 8;
	my $indent1 = 5;
	my $indent2 = 8;
	my $length =  @$data;
	my ($start,$i,$j,$line);
	my $width = $size{'max-cols-basic'};
	if ($width > 110){
		$indent_static = 22;
	}
	elsif ($width < 90){
		$indent_static = 15;
	}
	# print $length . "\n";
	for my $i (0 .. $#$data){
		# print "0: $data->[$i][0]\n";
		if ($data->[$i][0] == 0){
			$indent = 0;
			$indent1 = 0;
			$indent2 = 0;
		}
		elsif ($data->[$i][0] == 1){
			$indent = $indent_static;
			$indent1 = $indent1_static;
			$indent2= $indent2_static;
		}
		elsif ($data->[$i][0] == 2){
			$indent = ($indent_static + 7);
			$indent1 = ($indent_static + 5);
			$indent2 = 0;
		}
		$data->[$i][3] =~ s/\n/ /g;
		$data->[$i][3] =~ s/\s+/ /g;
		if ($data->[$i][1] && $data->[$i][2]){
			$data->[$i][1] = $data->[$i][1] . ', ';
		}
		$start = sprintf("%${indent1}s%-${indent2}s",$data->[$i][1],$data->[$i][2]);
		if ($indent > 1 && (length($start) > ($indent - 1))){
			$line = sprintf("%-${indent}s\n", "$start");
			print_line($line);
			$start = '';
			# print "1-print.\n";
		}
		if (($indent + length($data->[$i][3])) < $width){
			$data->[$i][3] =~ s/\^/ /g;
			$line = sprintf("%-${indent}s%s\n", "$start", $data->[$i][3]);
			print_line($line);
			# print "2-print.\n";
		}
		else {
			my $holder = '';
			my $sep = ' ';
			# note: special case, split ' ' trims leading, trailing spaces, 
			# then splits like awk, on one or more white spaces.
			foreach my $word (split(' ', $data->[$i][3])){
				# print "$word\n";
				if (($indent + length($holder) + length($word)) < $width){
					$word =~ s/\^/ /g;
					$holder .= $word . $sep;
					# print "3-hold.\n";
				}
				# elsif (($indent + length($holder) + length($word)) >= $width){
				else {
					$line = sprintf("%-${indent}s%s\n", "$start", $holder);
					print_line($line);
					$start = '';
					$word =~ s/\^/ /g;
					$holder = $word . $sep;
					# print "4-print-hold.\n";
				}
			}
			if ($holder !~ /^[ ]*$/){
				$line = sprintf("%-${indent}s%s\n", "$start", $holder);
				print_line($line);
				# print "5-print-last.\n";
			}
		}
	}
}

# This has to get a hash of hashes, at least for now. Because perl does not 
# retain insertion order, I use a prefix for each hash key to force sorts. 
sub print_data {
	my ($data) = @_;
	my ($counter,$length,$split_count) = (0,0,0);
	my ($hash_id,$holder,$holder2,$start,$start2,$start_holder) = ('','','','','','');
	my $indent = $size{'indent'};
	my (%ids);
	my ($b_container,$b_ni2,$key,$line,$val2,$val3);
	# these 2 sets are single logic items
	my $b_single = ($size{'max-cols'} == 1) ? 1: 0;
	my ($b_row1,$indent_2,$indent_use,$indentx) = (1,0,0,0);
	# $size{'max-cols'} = 88;
	# NOTE: indent < 11 would break the output badly in some cases
	if ($size{'max-cols'} < $size{'max-wrap'} || $size{'indent'} < 11){
		$indent = $size{'indents'};
	}
	foreach my $key1 (sort { substr($a,0,3) <=> substr($b,0,3) } keys %$data){
		$key = (split('#', $key1))[3];
		$b_row1 = 1;
		if ($key ne 'SHORT'){
			$start = sprintf("$colors{'c1'}%-${indent}s$colors{'cn'}","$key$sep{'s1'}");
			if ($use{'output-block'}){
				output_control() if $use{'output-block'} > 1;
				$use{'output-block'}++;
			}
			$start_holder = $key;
			$indent_2 = $indent + $size{'indents'};
			$b_ni2 = 0; # ($start_holder eq 'Info') ? 1 : 0;
			if ($indent < 10){
				$line = "$start\n";
				print_line($line);
				$start = '';
				$line = '';
			}
		}
		else {
			$indent = 0;
		}
		next if ref($data->{$key1}) ne 'ARRAY';
		# Line starters that will be -x incremented always
		# It's a tiny bit faster manually resetting rather than using for loop
		%ids = (
		'Array' => 1, # RAM or RAID
		'Battery' => 1,
		'Card' => 1,
		'Device' => 1,
		'Floppy' => 1,
		'Hardware' => 1, # hardware raid report
		'Hub' => 1,
		'ID' => 1,
		'IF-ID' => 1,
		'LV' => 1,
		'Monitor' => 1,
		'Optical' => 1,
		'Screen' => 1,
		'Server' => 1, # was 'Sound Server'
		'variant' => 1, # arm > 1 cpu type
		);
		foreach my $val1 (@{$data->{$key1}}){
			if (ref($val1) eq 'HASH'){
				if (!$b_single){
					$indent_use = $length = ($b_row1 && $key !~ /^(Features)$/) ? $indent : $indent_2;
				}
				($counter,$b_row1,$split_count) = (0,1,0);
				foreach my $key2 (sort {substr($a,0,3) <=> substr($b,0,3)} keys %$val1){
					($hash_id,$b_container,$indentx,$key) = (split('#', $key2));
					if (!$b_single){
						$indent_use = ($b_row1 || $b_ni2) ? $indent: $indent_2;
					}
					# print "m-1: r1: $b_row1 iu: $indent_use\n";
					if ($start_holder eq 'Graphics' && $key eq 'Screen'){
						$ids{'Monitor'} = 1;
					}
					elsif ($start_holder eq 'Memory' && $key eq 'Array'){
						$ids{'Device'} = 1;
					}
					elsif ($start_holder eq 'RAID' && $key eq 'Device'){
						$ids{'Array'} = 1;
					}
					elsif ($start_holder eq 'USB' && $key eq 'Hub'){
						$ids{'Device'} = 1;
					}
					elsif ($start_holder eq 'Logical' && $key eq 'Device'){
						$ids{'LV'} = 1;
					}
					if ($counter == 0 && defined $ids{$key}){
						$key .= '-' . $ids{$key}++;
					}
					$val2 = $val1->{$key2};
					# we have to handle cases where $val2 is 0
					if (!$b_single && $val2 || $val2 eq '0'){
						$val2 .= " ";
					}
					# See: Use of implicit split to @_ is deprecated. Only get this
					# warning in Perl 5.08 oddly enough. ie, no: scalar (split(...));
					my @values = split(/\s+/, $val2);
					$split_count = scalar @values;
					# print "sc: $split_count l: " . (length("$key$sep{'s2'} $val2") + $indent_use), " val2: $val2\n";
					if (!$b_single && 
					(length("$key$sep{'s2'} $val2") + $length) <= $size{'max-cols'}){
						# print "h-1: r1: $b_row1 iu: $indent_use\n";
						$length += length("$key$sep{'s2'} $val2");
						$holder .= "$colors{'c1'}$key$sep{'s2'}$colors{'c2'} $val2";
					}
					# Handle case where the key/value pair is > max, and where there are 
					# a lot of terms, like cpu flags, raid types supported. Raid can have
					# the last row have a lot of devices, or many raid types. But we don't
					# want to wrap things like: 3.45 MiB (6.3%)
					elsif (!$b_single && $split_count > 2 && length($val2) > 24 && 
					!defined $ids{$key} &&
					(length("$key$sep{'s2'} $val2") + $indent_use + $length) > $size{'max-cols'}){
						# print "m-2 r1: $b_row1 iu: $indent_use\n";
						$val3 = shift @values;
						$start2 = "$colors{'c1'}$key$sep{'s2'}$colors{'c2'} $val3 ";
						# Case where not first item in line, but when key+first word added,
						# is wider than max width.
						if ($holder && 
						 ($length + length("$key$sep{'s2'} $val3")) > $size{'max-cols'}){
							# print "p-1a r1: $b_row1 iu: $indent_use\n";
							$holder =~ s/\s+$//;
							$line = sprintf("%-${indent_use}s%s$colors{'cn'}\n","$start","$holder");
							print_line($line);
							$b_row1 = 0;
							$start = '';
							$holder = '';
							$length = $indent_use;
						}
						$length += length("$key$sep{'s2'} $val3 ");
						# print scalar @values,"\n";
						foreach (@values){
							# my $l =  (length("$_ ") + $length);
							# print "$l\n";
							$indent_use = ($b_row1 || $b_ni2) ? $indent : $indent_2;
							if ((length("$_ ") + $length) < $size{'max-cols'}){
								# print "h-2: r1: $b_row1 iu: $indent_use\n";
								# print "a\n";
								if ($start2){
									$holder2 .= "$start2$_ ";
									$start2 = '';
								}
								else {
									$holder2 .= "$_ ";
								}
								$length += length("$_ ");
							}
							else {
								# print "p-1b: r1: $b_row1 iu: $indent_use\n";
								if ($start2){
									$holder2 = "$start2$holder2";
								}
								else {
									$holder2 = "$colors{'c2'}$holder2";
								}
								# print "xx:$holder";
								$holder2 =~ s/\s+$//;
								$line = sprintf("%-${indent_use}s%s$colors{'cn'}\n","$start","$holder$holder2");
								print_line($line);
								# make sure wrapped value is indented correctly! 
								$b_row1 = 0;
								$indent_use = ($b_row1) ? $indent : $indent_2;
								$holder = '';
								$holder2 = "$_ ";
								# print "h2: $holder2\n";
								$length = length($holder2) + $indent_use;
								$start2 = '';
								$start = '';
							}
						}
						# We don't want to start a new line, continue until full length.
						if ($holder2 !~ /^\s*$/){
							# print "p-2: r1: $b_row1 iu: $indent_use\n";
							$holder2 = "$colors{'c2'}$holder2";
							$holder = $holder2;
							$b_row1 = 0;
							$holder2 = '';
							$start2 = '';
							$start = '';
						}
					}
					# NOTE: only these and the last fallback are used for b_single output
					else {
						if ($holder){
							# print "p-3: r1: $b_row1 iu: $indent_use\n";
							$holder =~ s/\s+$//;
							$line = sprintf("%-${indent_use}s%s$colors{'cn'}\n",$start,"$holder");
							$length = length("$key$sep{'s2'} $val2") + $indent_use;
							print_line($line);
							$b_row1 = 0;
							$start = '';
						}
						else {
							# print "h-3a: r1: $b_row1 iu: $indent_use\n";
							$length = $indent_use;
						}
						if ($b_single){
							$indent_use = ($indent * $indentx);
						}
						else {
							$indent_use = ($b_row1 || $b_ni2) ? $indent: $indent_2;
						}
						$holder = "$colors{'c1'}$key$sep{'s2'}$colors{'c2'} $val2";
						# print "h-3b: r1: $b_row1 iu: $indent_use\n";
					}
					$counter++;
				}
				if ($holder !~ /^\s*$/){
					# print "p-4:  r1: $b_row1 iu: $indent_use\n";
					$holder =~ s/\s+$//;
					$line = sprintf("%-${indent_use}s%s$colors{'cn'}\n",$start,"$start2$holder");
					print_line($line);
					$b_row1 = 0;
					$holder = '';
					$length = 0;
					$start = '';
				}
			}
			# Only for repos currently
			elsif (ref($val1) eq 'ARRAY'){
				# print "p-5: r1: $b_row1 iu: $indent_use\n";
				my $num = 0;
				my ($l1,$l2);
				$indent_use = $indent_2;
				foreach my $item (@$val1){
					$num++;
					if ($size{'max-lines'}){
						$l1 = length("$num$sep{'s2'} $item") + $indent_use;
						# Cut down the line string until it's short enough to fit in term
						if ($l1 > $size{'term-cols'}){
							$l2 = length("$num$sep{'s2'} ") + $indent_use + 6;
							# print "$l1 $size{'term-cols'} $l2 $num $indent_use\n";
							$item = substr($item,0,$size{'term-cols'} - $l2) . '[...]';
						}
					}
					$line = "$colors{'c1'}$num$sep{'s2'} $colors{'c2'}$item$colors{'cn'}";
					$line = sprintf("%-${indent_use}s%s\n","","$line");
					print_line($line);
				}
				
			}
		}
		# We want a space between data blocks for single
		print_line("\n") if $b_single;
	}
}

sub print_line {
	my ($line) = @_;
	if ($b_irc && $client{'test-konvi'}){
		$client{'konvi'} = 3;
		$client{'dobject'} = 'Konversation';
	}
	if ($client{'konvi'} == 1 && $client{'dcop'}){
		# konvi doesn't seem to like \n characters, it just prints them literally
		$line =~ s/\n//g;
		#qx('dcop "$client{'dport'}" "$client{'dobject'}" say "$client{'dserver'}" "$client{'dtarget'}" "$line 1");
		system('dcop', $client{'dport'}, $client{'dobject'}, 'say', $client{'dserver'}, $client{'dtarget'}, "$line 1");
	}
	elsif ($client{'konvi'} == 3 && $client{'qdbus'}){
		# print $line;
		$line =~ s/\n//g;
		#qx(qdbus org.kde.konversation /irc say "$client{'dserver'}" "$client{'dtarget'}" "$line");
		system('qdbus', 'org.kde.konversation', '/irc', 'say', $client{'dserver'}, $client{'dtarget'}, $line);
	}
	else {
		# print "tl: $size{'term-lines'} ml: $size{'max-lines'} l:$size{'lines'}\n";
		if ($size{'max-lines'}){
			# -y1 + -Y can result in start of output scrolling off screen if terminal
			# wrapped lines happen.
			if ((($size{'max-lines'} >= $size{'term-lines'}) && 
			$size{'max-lines'} == $size{'lines'}) ||
			($size{'max-lines'} < $size{'term-lines'} && 
			$size{'max-lines'} + 1 == $size{'lines'})){
				output_control();
			}
		}
		print $line;
		$size{'lines'}++ if $size{'max-lines'};
	}
}

########################################################################
#### ITEM PROCESSORS
########################################################################

#### -------------------------------------------------------------------
#### ITEM GENERATORS
#### -------------------------------------------------------------------

## AudioItem 
{