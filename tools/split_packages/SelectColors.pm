package SelectColors;
my (@data,%configs,%status);
my ($type,$w_fh);
my $safe_color_count = 12; # null/normal + default color group
my $count = 0;

# args: 0: type
sub new {
	my $class = shift;
	($type) = @_;
	my $self = {};
	return bless $self, $class;
}

sub select_schema {
	eval $start if $b_log;
	assign_selectors();
	main::set_color_scheme(0);
	set_status();
	start_selector();
	create_color_selections();
	if (!$b_irc){
		Configs::check_file();
		get_selection();
	}
	else {
		print_irc_message();
	}
	eval $end if $b_log;
}

sub set_status {
	$status{'console'} = (defined $colors{'console'}) ? "Set: $colors{'console'}" : 'Not Set';
	$status{'virt-term'} = (defined $colors{'virt-term'}) ? "Set: $colors{'virt-term'}" : 'Not Set';
	$status{'irc-console'} = (defined $colors{'irc-console'}) ? "Set: $colors{'irc-console'}" : 'Not Set';
	$status{'irc-gui'} = (defined $colors{'irc-gui'}) ? "Set: $colors{'irc-gui'}" : 'Not Set';
	$status{'irc-virt-term'} = (defined $colors{'irc-virt-term'}) ? "Set: $colors{'irc-virt-term'}" : 'Not Set';
	$status{'global'} = (defined $colors{'global'}) ? "Set: $colors{'global'}" : 'Not Set';
}

sub assign_selectors {
	if ($type == 94){
		$configs{'variable'} = 'CONSOLE_COLOR_SCHEME';
		$configs{'selection'} = 'console';
	}
	elsif ($type == 95){
		$configs{'variable'} = 'VIRT_TERM_COLOR_SCHEME';
		$configs{'selection'} = 'virt-term';
	}
	elsif ($type == 96){
		$configs{'variable'} = 'IRC_COLOR_SCHEME';
		$configs{'selection'} = 'irc-gui';
	}
	elsif ($type == 97){
		$configs{'variable'} = 'IRC_X_TERM_COLOR_SCHEME';
		$configs{'selection'} = 'irc-virt-term';
	}
	elsif ($type == 98){
		$configs{'variable'} = 'IRC_CONS_COLOR_SCHEME';
		$configs{'selection'} = 'irc-console';
	}
	elsif ($type == 99){
		$configs{'variable'} = 'GLOBAL_COLOR_SCHEME';
		$configs{'selection'} = 'global';
	}
}

sub start_selector {
	my $whoami = getpwuid($<) || "unknown???";
	if (!$b_irc){
		@data = (
		[ 0, '', '', "Welcome to $self_name! Please select the default 
		$configs{'selection'} color scheme."],
		);
	}
	push(@data, 
	[ 0, '', '', "Because there is no way to know your $configs{'selection'}
	foreground/background colors, you can set your color preferences from 
	color scheme option list below:"],
	[ 0, '', '', "0 is no colors; 1 is neutral."],
	[ 0, '', '', "After these, there are 4 sets:"],
	[ 0, '', '', "1-dark^or^light^backgrounds; 2-light^backgrounds; 
	3-dark^backgrounds; 4-miscellaneous"],
	[ 0, '', '', ""],
	);
	if (!$b_irc){
		push(@data, 
		[ 0, '', '', "Please note that this will set the $configs{'selection'} 
		preferences only for user: $whoami"],
		);
	}
	push(@data, 
	[ 0, '', '', "$line1"],
	);
	main::print_basic(\@data); 
	@data = ();
}

sub create_color_selections {
	my $spacer = '^^'; # printer removes double spaces, but replaces ^ with ' '
	$count = (main::get_color_scheme('count') - 1);
	foreach my $i (0 .. $count){
		if ($i > 9){
			$spacer = '^';
		}
		if ($configs{'selection'} =~ /^(global|irc-gui|irc-console|irc-virt-term)$/ && $i > $safe_color_count){
			last;
		}
		main::set_color_scheme($i);
		push(@data, 
		[0, '', '', "$i)$spacer$colors{'c1'}Card:$colors{'c2'}^nVidia^GT218 
		$colors{'c1'}Display^Server$colors{'c2'}^x11^(X.Org^1.7.7)$colors{'cn'}"],
		);
	}
	main::print_basic(\@data); 
	@data = ();
	main::set_color_scheme(0);
}

sub get_selection {
	my $number = $count + 1;
	@data = (
	[0, '', '', ($number++) . ")^Remove all color settings. Restore $self_name default."],
	[0, '', '', ($number++) . ")^Continue, no changes or config file setting."],
	[0, '', '', ($number++) . ")^Exit, use another terminal, or set manually."],
	[0, '', '', "$line1"],
	[0, '', '', "Simply type the number for the color scheme that looks best to your 
	eyes for your $configs{'selection'} settings and hit <ENTER>. NOTE: You can bring this 
	option list up by starting $self_name with option: -c plus one of these numbers:"],
	[0, '', '', "94^-^console,^not^in^desktop^-^$status{'console'}"],
	[0, '', '', "95^-^terminal,^desktop^-^$status{'virt-term'}"],
	[0, '', '', "96^-^irc,^gui,^desktop^-^$status{'irc-gui'}"],
	[0, '', '', "97^-^irc,^desktop,^in^terminal^-^$status{'irc-virt-term'}"],
	[0, '', '', "98^-^irc,^not^in^desktop^-^$status{'irc-console'}"],
	[0, '', '', "99^-^global^-^$status{'global'}"],
	[0, '', '',  ""],
	[0, '', '', "Your selection(s) will be stored here: $user_config_file"],
	[0, '', '', "Global overrides all individual color schemes. Individual 
	schemes remove the global setting."],
	[0, '', '', "$line1"],
	);
	main::print_basic(\@data); 
	@data = ();
	chomp(my $response = <STDIN>);
	if (!main::is_int($response) || $response > ($count + 3)){
		@data = (
		[0, '', '', "Error - Invalid Selection. You entered this: $response. Hit <ENTER> to continue."],
		[0, '', '',  "$line1"],
		);
		main::print_basic(\@data); 
		my $response = <STDIN>;
		start_selector();
		create_color_selections();
		get_selection();
	}
	else {
		process_selection($response);
	}
	if ($b_pledge){
		@pledges = grep {$_ ne 'getpw'} @pledges;
		OpenBSD::Pledge::pledge(@pledges);
	}
}

sub process_selection {
	my $response = shift;
	if ($response == ($count + 3)){
		@data = (
		[0, '', '', "Ok, exiting $self_name now. You can set the colors later."],
		);
		main::print_basic(\@data); 
		exit 0;
	}
	elsif ($response == ($count + 2)){
		@data = (
		[0, '', '', "Ok, continuing $self_name unchanged."],
		[0, '', '',  "$line1"],
		);
		main::print_basic(\@data); 
		if (defined $colors{'console'} && !$b_display){
			main::set_color_scheme($colors{'console'});
		}
		if (defined $colors{'virt-term'}){
			main::set_color_scheme($colors{'virt-term'});
		}
		else {
			main::set_color_scheme($colors{'default'});
		}
	}
	elsif ($response == ($count + 1)){
		@data = (
		[0, '', '', "Removing all color settings from config file now..."],
		[0, '', '',  "$line1"],
		);
		main::print_basic(\@data); 
		delete_all_config_colors();
		main::set_color_scheme($colors{'default'});
	}
	else {
		main::set_color_scheme($response);
		@data = (
		[0, '', '', "Updating config file for $configs{'selection'} color scheme now..."],
		[0, '', '',  "$line1"],
		);
		main::print_basic(\@data); 
		if ($configs{'selection'} eq 'global'){
			delete_all_colors();
		}
		else {
			delete_global_color();
		}
		set_config_color_scheme($response);
	}
}

sub delete_all_colors {
	my @file_lines = main::reader($user_config_file);
	open($w_fh, '>', $user_config_file) or main::error_handler('open', $user_config_file, $!);
	foreach (@file_lines){ 
		if ($_ !~ /^(CONSOLE_COLOR_SCHEME|GLOBAL_COLOR_SCHEME|IRC_COLOR_SCHEME|IRC_CONS_COLOR_SCHEME|IRC_X_TERM_COLOR_SCHEME|VIRT_TERM_COLOR_SCHEME)/){
			print {$w_fh} "$_"; 
		}
	} 
	close $w_fh;
}

sub delete_global_color {
	my @file_lines = main::reader($user_config_file);
	open($w_fh, '>', $user_config_file) or main::error_handler('open', $user_config_file, $!);
	foreach (@file_lines){ 
		if ($_ !~ /^GLOBAL_COLOR_SCHEME/){
			print {$w_fh} "$_"; 
		}
	} 
	close $w_fh;
}

sub set_config_color_scheme {
	my $value = shift;
	my @file_lines = main::reader($user_config_file);
	my $b_found = 0;
	open($w_fh, '>', $user_config_file) or main::error_handler('open', $user_config_file, $!);
	foreach (@file_lines){ 
		if ($_ =~ /^$configs{'variable'}/){
			$_ = "$configs{'variable'}=$value";
			$b_found = 1;
		}
		print $w_fh "$_\n";
	}
	if (!$b_found){
		print $w_fh "$configs{'variable'}=$value\n";
	}
	close $w_fh;
}

sub print_irc_message {
	@data = (
	[ 0, '', '', "$line1"],
	[ 0, '', '', "After finding the scheme number you like, simply run this again
	in a terminal to set the configuration data file for your irc client. You can 
	set color schemes for the following: start inxi with -c plus:"],
	[ 0, '', '', "94 (console,^not^in^desktop^-^$status{'console'})"],
	[ 0, '', '', "95 (terminal, desktop^-^$status{'virt-term'})"],
	[ 0, '', '', "96 (irc,^gui,^desktop^-^$status{'irc-gui'})"],
	[ 0, '', '', "97 (irc,^desktop,^in terminal^-^$status{'irc-virt-term'})"],
	[ 0, '', '', "98 (irc,^not^in^desktop^-^$status{'irc-console'})"],
	[ 0, '', '', "99 (global^-^$status{'global'})"]
	);
	main::print_basic(\@data); 
	exit 0;
}
}

#### -------------------------------------------------------------------
#### CONFIGS
#### -------------------------------------------------------------------

## Configs
# public: set() check_file()
{