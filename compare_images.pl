use strict;
use warnings;

my $threshold = shift @ARGV;
my $default = shift @ARGV;
my $folder = shift @ARGV;

sub get_colors {
	my $img = shift;
	my $str = qq#convert $img -resize 1x1\! -format "%[fx:int(255*r+.5)],%[fx:int(255*g+.5)],%[fx:int(255*b+.5)]" info:-#;
	my $output = qx($str);
	return split(/,/, $output);
}

sub is_in_threshold {
	my $default_number = shift;
	my $check_number = shift;

	my $threshold_add_or_subtract = int($default_number * ((100 - $threshold) / 100) + 1);

	#die "default: $default_number, check: $check_number, add: +-$threshold_add_or_subtract";

	if (($default_number - $threshold_add_or_subtract) <= $check_number && $check_number <= ($default_number + $threshold_add_or_subtract)) {
		return 1;
	} else {
		return 0;
	}
}

my $i = 1;

my @default_color = get_colors($default);
my ($default_r, $default_g, $default_b) = @default_color;

foreach my $file (<$folder/*.jpg>) {
	my @color = get_colors($file);
	my ($r, $g, $b) = @color;
	warn "$r $g $b\n";
	if(is_in_threshold($default_r, $r) && is_in_threshold($default_g, $g) && is_in_threshold($default_b, $b)) {
		print "$i\n";
		exit;
	}
	$i++;
}
