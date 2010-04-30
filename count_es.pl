#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use 5.10.0;

binmode STDOUT, ':utf8';

use constant directory => 'archives/';
use constant list_url  => 'http://mail.pm.org/pipermail/';

use URI;
use Carp qw/croak/;
use Mail::Box::Manager;
use WWW::Mechanize;
use HTML::TreeBuilder::XPath;

my %count_subject;

start_list('saopaulo-pm/');

=head2 the job 

    Responsável por imprimir os subjects com os ES

=cut

sub the_job {
    foreach my $mail ( @{ messages(shift) } ) {
        count_subject( $mail->subject );
    }
    print_subject(%count_subject);
    %count_subject = ();
}

=head2 print_subject 

    Imprime os Encontros Sociais válidos.

=cut

sub print_subject {
    my %subjects = @_;
    return unless @_;
    for my $sub ( sort { $subjects{$a} <=> $subjects{$b} } keys %subjects ) {
        say "\t", $subjects{$sub}, '=>', $sub if $subjects{$sub} >= 3;
    }
}

=head2 count_subject

    Conta os assuntos que tem [ES].

=cut

sub count_subject {
    my $message = shift;
    return if $message =~ /res:\s+|Was[\s:]|resumo|quando|\?/ig;
    if ( $message =~ /\[es\]|Encontro\sSocial/i ) {
        $count_subject{$message}++;
    }
}

=head2 messages 

    Retorna todas as mensagens de email

=cut

sub messages {
    my $mgr = Mail::Box::Manager->new;
    my $folder = $mgr->open( folder => ( directory . shift ) );
    return [ $folder->messages ];
}

=head2 my_files

  Pega todos os arquivos no diretório archives e retorna a lista dos arquivos.

=cut

sub my_files {
    opendir my $dir, directory or die $!;
    return [ grep { !/^\./ } readdir($dir) ];
}

=head2 start_list 

    Baixa os arquivos da lista escolhida

=cut

sub start_list {
    my $list_name = shift;
    for my $url ( @{ baixar_lista_content($list_name) } ) {
        say $url->attr('href');
        my ( $content, $filename )
            = content( list_url . $list_name . '/' . $url->attr('href') );
        save_file( $filename, $content );
        the_job($filename);
    }
}

=head2 baixar_lista_content

    Retorna as URLS para baixar as threads.

=cut

sub baixar_lista_content {
    my $tree = HTML::TreeBuilder::XPath->new_from_content(
        ( ( content( list_url . shift ) )[0] ) );
    return [ grep { $_->as_text =~ /Text/ } $tree->findnodes('//a') ];
}

=head2 content_list

    Retorna o content do HTML;

=cut

sub content {
    my $uri  = shift;
    my $mech = WWW::Mechanize->new();
    $mech->get($uri);
    return ( $mech->content, file_name($uri) );
}

=head2 file_name

    Retorna o nome do arquivo.

=cut

sub file_name {
    my $uri = URI->new(shift);
    return ( ( $uri->path_segments )[-1] );
}

=head2 save_files 

    Salva os arquivos da lista no archives/

=cut

sub save_file {
    open my $file, '>', ( directory . shift ) or croak $!;
    print $file shift;
    return close $file;
}
