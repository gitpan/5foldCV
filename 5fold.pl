#!/usr/bin/perl

use strict;
use warnings;
use File::Basename;
use Statistics::R;
use List::Util 'shuffle';


my $directory = $ARGV[0];
my $dir = dirname($directory);
my $file = basename($directory);
$file =~ s/\.txt//g;
my $newdir= "$dir$file";
mkdir("$newdir", 0777) or die "$!";
open IN,"<","$dir/$file.txt" or die "$!";
my (%col_pos,%col_neg,%col_line);
my ($totalPos,$totalNeg);
my $title = <IN>;
while(<IN>){
    my @in = split /\t/;
    if($in[1] == 1){
    	$col_pos{$in[0]} = $in[1];
        $totalPos++;
    }
    if($in[1] == -1){
    	$col_neg{$in[0]} = $in[1];
        $totalNeg++;
    }
    $col_line{$in[0]} = $_;
}

my @keyPos = shuffle keys %col_pos;
my @keyNeg = shuffle keys %col_neg;
my $averPos = int($totalPos/5);
my $averNeg = int($totalNeg/5);

my $train_start = 1;
my $train_end = ($averPos + $averNeg)*4;
my $test_start = $train_end + 1;
my $test_end = ($averPos + $averNeg)*5;

&out($averPos,$averNeg,1);
&out($averPos,$averNeg,2);
&out($averPos,$averNeg,3);
&out($averPos,$averNeg,4);
&out($averPos,$averNeg,5);

my $averSE = 0;
my $averSP = 0;
my $averACC = 0;
my $averMCC = 0;

open LOG,">","$newdir/log.txt" or die "$!";
print "CV\tTP\tFN\tSE\tTN\tFP\tSP\tACC\tMCC\n";
print LOG "CV\tTP\tFN\tSE\tTN\tFP\tSP\tACC\tMCC\n";
&comb(2,3,4,5,1);
&comb(1,3,4,5,2);
&comb(1,2,4,5,3);
&comb(1,2,3,5,4);
&comb(1,2,3,4,5);
$averSE = sprintf "%.2f",$averSE/5;
$averSP = sprintf "%.2f",$averSP/5;
$averACC = sprintf "%.2f",$averACC/5;
$averMCC = sprintf "%.3f",$averMCC/5;
print "average\t\t\t$averSE\t\t\t$averSP\t$averACC\t$averMCC\n";
print LOG "average\t\t\t$averSE\t\t\t$averSP\t$averACC\t$averMCC\n";
close LOG;

sub out {
    my ($averPos,$averNeg,$index) = @_;
    my $startPos = $averPos*($index-1);
    my $endPos = $averPos*$index-1;
    my $startNeg = $averNeg*($index-1);
    my $endNeg = $averNeg*$index-1;
    open OUT,">","$newdir/$index.txt" or die "$!";
    for my $col ($startPos..$endPos){
        print OUT $col_line{$keyPos[$col]};
    }
    for my $col ($startNeg..$endNeg){
        print OUT $col_line{$keyNeg[$col]};
    }
    close OUT;
}
sub comb {
    my ($i1,$i2,$i3,$i4,$i5) = @_;
    my $output = "$i1$i2$i3$i4$i5.txt";
	open OUT,">","$newdir/$output" or die "$!";
  print OUT $title;
  &in($i1);
	&in($i2);
	&in($i3);
	&in($i4);
	&in($i5);
	close OUT;
#	&R($i5,$train_start,$train_end,$test_start,$test_end,$output);
	&R($i5,$output);
}
sub in {
    my $index = shift;
    open IN,"<","$newdir/$index.txt" or die "$1";
	while(<IN>){
	    print OUT $_;
	}
	close IN;
}

sub R {
    my ($index,$output) = @_;
    print "$index\t";
    print LOG "$index\t";
    my $R = Statistics::R -> new();
    $R -> startR;
    $R -> send(qq'library(class)');
    $R -> send(qq'library(e1071)');
    $R -> send(qq'svmdata <- read.delim("$newdir/$output",header = TRUE,sep = "\t")');
    $R -> send(qq'n <- length(svmdata)');
    $R -> send(qq'trainset <- svmdata[$train_start:$train_end,3:n]');
    $R -> send(qq'trainlabel <- svmdata[$train_start:$train_end,2]');
    $R -> send(qq'testset <- svmdata[$test_start:$test_end,3:n]');
    $R -> send(qq'testlabel <- svmdata[$test_start:$test_end,2]');
    $R -> send(qq'model <- svm(trainset,trainlabel,type="C-classification")');
    $R -> send(qq'predlabel <- predict(model,testset)');
    $R -> send(qq'result <- table(predlabel,testlabel)');
    $R -> send(qq'TP <- result[2,2]');
    $R -> send(qq'print(TP)');
    my $read = $R -> read;
    my @read = split/\s+/,$read;
    $read = $read[1];
    print "$read\t";
    print LOG "$read\t";
    $R -> send(qq'FN <- result[2,1]');
    $R -> send(qq'print(FN)');
    $read = $R -> read;
    @read = split/\s+/,$read;
    $read = $read[1];
    print "$read\t";
    print LOG "$read\t";
    $R -> send(qq'SE <- TP/(TP+FN)');
    $R -> send(qq'print(SE)');
    $read = $R -> read;
    $read = &format($read);
    $averSE = $averSE + $read;
    print "$read\t";
    print LOG "$read\t"; 
    $R -> send(qq'TN <- result[1,1]');
    $R -> send(qq'print(TN)');
    $read = $R -> read;
    @read = split/\s+/,$read;
    $read = $read[1];
    print "$read\t";
    print LOG "$read\t";
    $R -> send(qq'FP <- result[1,2]');
    $R -> send(qq'print(FP)');
    $read = $R -> read;
    @read = split/\s+/,$read;
    $read = $read[1];
    print "$read\t";
    print LOG "$read\t";
    $R -> send(qq'SP <- TN/(TN+FP)');
    $R -> send(qq'print(SP)');
    $read = $R -> read;
    $read = &format($read);
		$averSP = $averSP + $read;
    print "$read\t";
    print LOG "$read\t";
    $R -> send(qq'ACC <- (TP+TN)/(TP+TN+FP+FN)');
    $R -> send(qq'print(ACC)');
    $read = $R -> read;
    $read = &format($read);
    $averACC = $averACC + $read;
    print "$read\t";
    print LOG "$read\t";
    $R -> send(qq'MCC <- (TP*TN-FN*FP)/sqrt((TP+FN)*(TP+FP)*(TN+FN)*(TN+FP))');
    $R -> send(qq'print(MCC)');
    $read = $R -> read;
    @read = split/\s+/,$read;
    $read = sprintf "%.3f", $read[1];
    $averMCC = $averMCC + $read;
    print "$read\n";
    print LOG "$read\n";
    $R -> stopR();
}
sub format {
    my $figure = shift;
    my @figure = split/\s+/,$figure;
    $figure = sprintf "%.2f", $figure[1]*100;
}