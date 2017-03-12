#!/usr/bin/perl
use strict; use warnings;

# ================ parameters =====================

# name of search
my $n = "[car]";

# fn: file name, file containing IDs of ads seen so far
my $fn = "log.txt";

# (*)
# - the list of already known ad IDs from the log file
# - data file format: list of ad IDs separated by space
# - default (if the data file does not yet exist): leave the list empty
my %idList = ();

# search URL and browser type (bro)
my $url="http://sfbay.craigslist.org/search/cto/sfc?query=Toyota|Honda|Acura&srchType=T&minAsk=2000&maxAsk=3500&hasPic=1";
my $bro = "Mozilla/5.0 (Windows NT 6.0; rv:2.0.1) Gecko/20100101 Firefox/4.0.1";

# delay (in seconds) between two downloads
my $wait = "600"; # 10 min
#my $wait = "30";

# list of email addresses
my @emails = qw/ EMAIL_1 EMAIL_2 /;
#my @emails = qw/ EMAIL_1 /;

# ============ main program ===============

# download URL every 'wait' seconds
do{
    # read the current list of IDs from the data file
    # see also above at (*)
    # $l: data line, remove starting and trailing whitespaces from it
    if( -f $fn ){ open IN, $fn; my $l=<IN>; $l=~s/^\s+//; $l=~s/\s+$//; %idList = map{$_=>1} split m/\s+/, $l; close IN; }

    # the shell command for downloading data (note: wget's log is discarded, goes into /dev/null)
    my $shCmd = "wget \"$url\" -O - -o /dev/null -U \"$bro\" | ";
    
    # current search results (html formatted from craigslist)
    open IN, $shCmd; my $hitsHtml = join("",<IN>); close IN;
    $hitsHtml =~ s/\&nbsp\;/\ /g; # remove all html formatted (no-break) spaces with a single space

    # list of current ad IDs and their titles
    # get price and location info too
    my %idListCurrent_2_title = 
        map{ s/<.*?>//g; s/\s+/\ /g; $_ } # remove html tags and replace multiple consecutive whitespace with one space
        ($hitsHtml =~ /href[^>]+?\/sfc\/cto\/(\d+)\.html\">([\d\D]+?)<br\ class=\"c\"/g);

    # the list of new IDs out of the current IDs
    my @idListNew = grep{ ! defined $idList{$_} } keys %idListCurrent_2_title;

    # IF   there is at least one new hit,
    # THEN send email(s) to the requested address(es)
    if( @idListNew ){
        # email title
        my $title = $n." ".(scalar @idListNew)." new search hit".( 1 < scalar @idListNew ? "s" : "");
        # print email body into a file
        my $body = join("\n", map{ $idListCurrent_2_title{$_}." (http://sfbay.craigslist.org/sfc/cto/".$_.".html)" }
                              sort {$a<=>$b} @idListNew);
        open OUT, ">email_body.txt"; print OUT $body; close OUT;

        # send emails to the requested addresses
        for my $emailAddress (@emails){
            my $shCmd = "/usr/bin/mail -s \"$title\" $emailAddress < email_body.txt";
            #print $shCmd."\n"; exit(0);
            system($shCmd);
        }
        
        # save IDs into the ID list and the data file
        for(@idListNew){++$idList{$_}}
        open OUT, ">".$fn; print OUT "".join(" ",sort {$a<=>$b} keys %idList); close OUT;
    }

    # wait for 'wait' seconds and then check search results again
    sleep $wait;

}while( 1 );
