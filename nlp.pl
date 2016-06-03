#!/usr/bin/perl
 
use strict; 
 
use CGI qw(param);
  
print "Content-type: text/html\n\n";
  
my $q = new CGI;
 
my $string = $q->param('string');
my $style = $q->param('style');
my $rules = lc $q->param('rules');
my $debug = lc $q->param('debug');
 
print <<EOF;
<html>
<link rel="stylesheet" href="/styles/global.css" type="text/css">
 
<font face="arial">
<h4>Basic Sentiment analyser</h4>
<form name="input" method="post">
<table>
<tr>
 <td>Text to be analysed:</td>
 <td><textarea cols=100 rows=4 name="string">$string</textarea></td>
</tr>
<tr>
 <td>Analyse text by:</td>
 <td title="Sentences are split on a full stop.  This is a crude method and words with dots in (such as Mr. or floating point numbers) will fool this.  Line break gives a better analysis at the paragraph level"><input type="radio" name="style" value="sentence" checked>Sentence
<input type="radio" name="style" value="linebreak">Line Break
<input type="hidden" name=debug value="$debug">
</td>
</tr>
<tr>
 <td colspan=2><input type="submit" value="submit"></td>
</tr>
</table>
</form>
 
EOF
 
exit 0 if ( $string eq "" and $rules ne "true" ) ;
 
# Read in the control file of :
#   Positive words
#   Negative words
#   Words which should be ignored
#   Words which boost a positive/negative words.  e.g. "really" good
#   Words which negate a positive/negative word.  e.g. "not" good
 
my @nlpConf = `cat nlp.conf`;
if ( $#nlpConf == -1 ) {
  print "<B>No NLP control file found - unable to perform analysis<\B>";
  exit 0;
}
 
my %nlp;
foreach my $line ( @nlpConf ) {
  next if ( $line =~ /^(#\s)/ );
  chomp $line;
  print "$line <BR>" if ( $rules eq "true" );
  ( my $type, my $word, my $value ) = split '\s', $line;
  $value = 1 if ( $value eq "" );
  $nlp{$type}{$word} = $value;
  $nlp{'allwords'}{$word} = $word;
}
 
# Process each message
my @messages;
 
# Break up input string into chunks based on user preference
if ( $style eq "sentence" ) { 
  # Flawed assumption that a dot indicates end of sentence. 
  # Abbreviations, etc, will break this.  e.g. Mr. Jones was born 31st Nov. 2001
  @messages = split '\.', $string;
} 
elsif ( $style eq "linebreak" ) { 
  @messages = split '\n', $string;
}
 
my $overallScore = 0; # Scoring for entire input
my $lines = 0;
print <<EOF;
<table border=1>
<tr><th>Sentiment<th>Segment Score<th>Output Message</th></tr>
EOF
# Process each chunk
for ( $a=0; $a <= $#messages; $a++ ) {
  my $msg = @messages[$a];
  my $msgOut = "";	# Used to build a sanitised output string
  chomp $msg;
 
  $msg =~ s/[^A-Za-z0-9 ]//g;	# Remove unwanted characters
 
  next if ( $msg eq "");	# Drop blank lines
 
  # Now split into individual words based on whitespace
  my @words = split ' ', $msg;
 
  my $pos = 0;	# Positive score
  my $neg = 0;	# Negative score
 
  # Analyse each word
  my $prevWord = "";	# Used to store previous "significant" word
  for ( my $i=0; $i <= $#words; $i++ ) {
    my $word = lc @words[$i];
 
    # Don't worry if this word isn't "significant" 
    if ( $nlp{'allwords'}{$word} eq "" ) { 
      $msgOut .= " @words[$i]";
      next;
    }
 
    my $booster = 1;	# Used to boost a word score
    # Check if previous word is a booster word and store the multiplier value
    if ( $nlp{'booster'}{$prevWord} ) { 
      $booster = $nlp{'booster'}{$prevWord} ;
    }
 
    if ( $debug eq "true" ) {
      print "CurrentWord:$word PrevWord:$prevWord PosScore:$nlp{'positive'}{$word} NegScore:$nlp{'negative'}{$word} Negator:$nlp{'negate'}{$prevWord} <BR>";
    } 
 
    # Analyse the word and basic context
    my $sent = "neutral";
 
    # Positive word and previous word not a negating word
    if ( $nlp{'positive'}{$word} and ! $nlp{'negate'}{$prevWord} ) { 
      $pos += ( $nlp{'positive'}{$word} * $booster );
      $sent = "positive";
    }
    # Negative word and previous word is a negating word
    elsif ( $nlp{'negative'}{$word} and $nlp{'negate'}{$prevWord} ) { 
      $pos += ( $nlp{'negative'}{$word} * $booster );
      $sent = "positive";
    }
    # Negative word and previous word not a negating word
    elsif ( $nlp{'negative'}{$word} and ! $nlp{'negate'}{$prevWord} ) { 
      $neg += ( $nlp{'negative'}{$word} * $booster );
      $sent = "negative";
    }
    # Positive word and previous word is a negating word
    elsif ( $nlp{'positive'}{$word} and $nlp{'negate'}{$prevWord} ) { 
      $neg += ( $nlp{'positive'}{$word} * $booster );
      $sent = "negative";
    }
 
    # Apply some formatting
    if ( $sent eq "positive" ) {
      $msgOut .= " <font color=GREEN>@words[$i]</font>";
    }
    elsif ( $sent eq "negative" ) {
      $msgOut .= " <font color=RED>@words[$i]</font>";
    }
    else {
      $msgOut .= " @words[$i]";
    }
 
    # Replace any unwanted words.  e.g. bad language
    if ( $nlp{'replace'}{$word} ) {
      $msgOut =~ s/$word/$nlp{'replace'}{$word}/;
    }
 
    # If current word is "significant", then store for future use
    if ( ! $nlp{'allwords'}{$prevWord} ) {
      $prevWord = $word;  # Store Previous "significant" word
    }
  }
 
  $lines++;
  # Work out overall score
  my $result = $pos - $neg;
  $overallScore += $result;
 
  # Some more formatting
  my $bg = "GREY";
  my $fcolor = "WHITE";
  my $sentiment = "Neutral";
 
  if ( $result > 0 ) {
    $bg = "GREEN";
    $sentiment = "Positive";
  }
  elsif ( $result < 0 ) {
    $bg = "RED";
    $sentiment = "Negative";
  }
 
  print <<EOF;
<tr><td style="background-color:$bg"><font style="color:$fcolor;">$sentiment</font></td><td>$result</td><td>$msgOut</td></tr>
EOF
 
}
my $averageScore = $overallScore / $lines;
 
print " </table><BR><BR>";
my $bg = "GREY";
my $fcolor = "WHITE";
my $sentiment = "Neutral";
 
if ( $overallScore > 0 ) {
  $bg = "GREEN";
  $sentiment = "Positive";
}
elsif ( $overallScore < 0 ) {
  $bg = "RED";
  $sentiment = "Negative";
}
print <<EOF;
<table border=1>
<tr><th colspan=2>Overall Sentiment</th><th>Average Score</th></tr>
<tr><td style="background-color:$bg;"><font style="color:$fcolor;">$sentiment</font></td><td title="Overall score for document">$overallScore</td><td title="Total score divided by # lines">$averageScore</td></tr>
</table>
EOF
 
exit 0;