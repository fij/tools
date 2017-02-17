#!/usr/bin/perl
# --- May-10-2008 ---
#
# get full train timetable between Gyor-Budapest
use strict; use warnings; use utf8;

# STATION ID, Gyor: 1358
# OTHER STATION match: Budapest

# download page containing the trains
my $cmd="wget -O - -o .log.txt ".
    "\"http://elvira.mav-start.hu/elvira.dll/xslms/af?i=1358&mind=1\" |";
open IN, "$cmd"; my $lines=join("",<IN>); close IN;

# loop through the list of trains through Gyor
for my $trainId (map{ /ELVIRA.VT\((\d+)\)/; $1; } # select train ID
                 map{ (/\<td.*?\>([\d\D]*?)\<\/td.*?\>/g)[2]; } # 2nd field
                 ($lines=~/\<tr.*?\>([\d\D]+?)\<\/tr.*?\>/g) # table lines
                ){
    #
    # get the page for this train
#    my $cmd2 = "wget -O - -o .log$trainId.txt ".
    my $cmd2 = "wget -O - -o .log.txt ".
        "\"http://elvira.mav-start.hu/elvira.dll/xslms/vt?v=".$trainId."\" | ";
    open IN2, "$cmd2"; my $lines2=join("",<IN2>); close IN2;
    #
    # extract train info
    # keep only trains where Budapest is listed in the table
    if( $lines2 =~ /\<h2\>.*?(\d+).*?\<\/h2.*?
                    \<h3\>\s*(.*?)\s*\<\/h3.*?
                    \<span.*?\>(.*?)\<\/span.*?
                    zlekedik.*?\<li\>(.*?)\<\/li.*?
                    \<table.*?\>(.*?Budapest.*?)\<\/table
                   /sx )
    {
        my ($trainNum,$fromTo,$trainType,$whatDays,$table)= ($1,$2,$3,$4,$5);

        # abbreviating names
        my %n2n = ( "Gy" => "Gyor", "Kelen" => "Kfld", "Nyug" => "BpNy",
                    "Kelet" => "BpKe", "li pu" => "BpDe", "Budapest-D" => "BpDe",
                    "nemzet" => "nemz", "belf" => "belf", 
                    "szem" => "sz", "gyors" => "gy",
                    "nterCit" => "IC", "EuroNight" => "EuNight", "EuroCity" => "EC", 
                    "tf" => "H", "edd" => "K", "zerda" => "Sze", "rt" => "Cs",
                    "ntek" => "P", "ombat" => "Szo", "rnap" => "V", );

        # Gyor and Budapest stations of this train
        my @st =
            map{ s/\s*pu\.//g; $_ } # remove "pu." 
            map{ for ($_->[1],$_->[2]){if(!/\d/){ $_ ="--:--"; } }
                 $_->[0]." ".$_->[1]." ".$_->[2] } # replace empty arrival or dept. time with --:--
            map{ [ (/\<td.*?\> # station, arrival, departure
                   (\<a.*?\>)*\s* (.*?) \s*(\<\/a.*?\>)* # discard hyperlink (note: 3 memory items)
                   \<\/td/gxs # loop through the columns
                   )[4,7,10] # keep 2nd item (of 3) from 2nd,3rd,4th columns
                 ] } # return unnamed list
            grep{ /ELVIRA\.AF\(1358|Budapest/ } # use stations: Gyor (358) or Bp. (several stations)
            ( $table =~ /\<tr.*?\>(.*?)\<\/tr/gxs ); # loop throug the lines of the table

        my $sched =
            join(" ",(@st,$whatDays,$trainType));
        while(my($patt,$short)=each%n2n){ $sched =~ s/\S*$patt\S*/$short/g; }
        $sched =~ s/\b(\d\:)/0$1/g; # add zero prefix to one-digit hour
        $sched =~ s/\<\/*a.*?\>//g; # remove html tags
        $sched =~ s/\n/ /xsg; # remove newlines
        $sched =~ s/\s+/ /xsg; # shorten whitespaces
        $sched =~ s/<C3><A9>s\s*//g; # remove "and" (<C3><A9>s)
        $sched =~ s/\d-t\Sl\s*(\S+)\-ig/\-$1/; # replace -tol -ig
        print $sched."\n";

#       print $lines2;
#       print join(" -- ",($trainNum,$fromTo,$trainType,$whatDays))."\n";exit(1);
    }
}
