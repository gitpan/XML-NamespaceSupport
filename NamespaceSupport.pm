
###
# XML::NamespaceSupport - a simple generic namespace processor
# Robin Berjon <robin@knowscape.com>
# 20/09/2001 - v0.02 (w/ lots from Duncan Cameron)
# 16/09/2001 - v.0.01
###

package XML::NamespaceSupport;
use strict;

use vars qw($VERSION);
$VERSION = '0.03';
use constant NS_XMLNS   => 'http://www.w3.org/2000/xmlns/';
use constant NS_XML     => 'http://www.w3.org/XML/1998/namespace';


#-------------------------------------------------------------------#
# constructor
#-------------------------------------------------------------------#
sub new {
    my $class   = ref($_[0]) ? ref(shift) : shift;
    my $options = shift;
    my $self = {
                fatals  => 1,
                nsmap   => [{
                              default       => undef,
                              prefix_map    => { xml => NS_XML },
                              declarations  => undef,
                           }]
               };
    $self->{nsmap}->[0]->{prefix_map}->{xmlns} = NS_XMLNS if $options->{xmlns};
    $self->{fatals} = $options->{fatal_errors} if defined $options->{fatal_errors} ;
    return bless $self, $class;
}
#-------------------------------------------------------------------#

#-------------------------------------------------------------------#
# reset() - return to the original state (for reuse)
#-------------------------------------------------------------------#
sub reset {
    my $self = shift;
    $#{$self->{nsmap}} = 0;
}
#-------------------------------------------------------------------#

#-------------------------------------------------------------------#
# push_context() - add a new empty context to the stack
#-------------------------------------------------------------------#
sub push_context {
    my $self = shift;
    push @{$self->{nsmap}}, {
                             default         => $self->{nsmap}->[-1]->{default},
                             prefix_map      => { %{$self->{nsmap}->[-1]->{prefix_map}} },
                             declarations    => [],
                            };
}
#-------------------------------------------------------------------#

#-------------------------------------------------------------------#
# pop_context() - remove the topmost context fromt the stack
#-------------------------------------------------------------------#
sub pop_context {
    my $self = shift;
    die 'Trying to pop context without push context' unless @{$self->{nsmap}} > 1;
    pop @{$self->{nsmap}};
}
#-------------------------------------------------------------------#

#-------------------------------------------------------------------#
# declare_prefix() - declare a prefix in the current scope
#-------------------------------------------------------------------#
sub declare_prefix {
    my $self    = shift;
    my $prefix  = shift;
    my $value   = shift;

    return 0 if $prefix =~ /^xml/i;

    if ($prefix eq '') {
        $self->{nsmap}->[-1]->{default} = $value;
    }
    else {
        die "Cannot undeclare prefix $prefix" if $value eq '';
        $self->{nsmap}->[-1]->{prefix_map}->{$prefix} = $value;
    }
    push @{$self->{nsmap}->[-1]->{declarations}}, $prefix;
    return 1;
}
#-------------------------------------------------------------------#

#-------------------------------------------------------------------#
# declare_prefixes() - declare several prefixes in the current scope
#-------------------------------------------------------------------#
sub declare_prefixes {
    my $self     = shift;
    my %prefixes = @_;
    while (my ($k,$v) = each %prefixes) {
        $self->declare_prefix($k,$v);
    }
}
#-------------------------------------------------------------------#

#-------------------------------------------------------------------#
# get_prefix() - get a (random) prefix for a given URI
#-------------------------------------------------------------------#
sub get_prefix {
    my $self    = shift;
    my $uri     = shift;

    while (my ($k, $v) = each %{$self->{nsmap}->[-1]->{prefix_map}}) {
        return $k if $v eq $uri;
    }
    return undef;
}
#-------------------------------------------------------------------#

#-------------------------------------------------------------------#
# get_prefixes() - get all the prefixes for a given URI
#-------------------------------------------------------------------#
sub get_prefixes {
    my $self    = shift;
    my $uri     = shift;

    return keys %{$self->{nsmap}->[-1]->{prefix_map}} unless defined $uri;
    return grep { $self->{nsmap}->[-1]->{prefix_map}->{$_} eq $uri } keys %{$self->{nsmap}->[-1]->{prefix_map}};
}
#-------------------------------------------------------------------#

#-------------------------------------------------------------------#
# get_declared_prefixes() - get all prefixes declared in the last context
#-------------------------------------------------------------------#
sub get_declared_prefixes {
    my $self = shift;
    return @{$self->{nsmap}->[-1]->{declarations}};
}
#-------------------------------------------------------------------#

#-------------------------------------------------------------------#
# get_uri() - get an URI given a prefix
#-------------------------------------------------------------------#
sub get_uri {
    my $self    = shift;
    my $prefix  = shift;

    return $self->{nsmap}->[-1]->{default} if $prefix eq '';
    return $self->{nsmap}->[-1]->{prefix_map}->{$prefix} if exists $self->{nsmap}->[-1]->{prefix_map}->{$prefix};
    return undef;
}
#-------------------------------------------------------------------#

#-------------------------------------------------------------------#
# process_name() - provide details on a name
#-------------------------------------------------------------------#
sub process_name {
    my $self    = shift;
    my $qname   = shift;
    my $aflag   = shift;

    my ($ns, $lname);
    eval {
        ($ns, undef, $lname) = $self->_get_ns_details($qname, $aflag);
    };
    if ($@) {
        die $@ if $self->{fatals};
        return undef;
    }
    return ($ns, $lname, $qname);
}
#-------------------------------------------------------------------#

#-------------------------------------------------------------------#
# process_element_name() - provide details on a element's name
#-------------------------------------------------------------------#
sub process_element_name {
    my $self    = shift;
    my $qname   = shift;

    my ($ns, $prefix, $lname);
    eval {
        ($ns, $prefix, $lname) = $self->_get_ns_details($qname, 0);
    };
    if ($@) {
        die $@ if $self->{fatals};
        return undef;
    }
    return ($ns, $prefix, $lname);
}
#-------------------------------------------------------------------#


#-------------------------------------------------------------------#
# process_attribute_name() - provide details on a attribute's name
#-------------------------------------------------------------------#
sub process_attribute_name {
    my $self    = shift;
    my $qname   = shift;

    my ($ns, $prefix, $lname);
    eval {
        ($ns, $prefix, $lname) = $self->_get_ns_details($qname, 1);
    };
    if ($@) {
        die $@ if $self->{fatals};
        return undef;
    }
    return ($ns, $prefix, $lname);
}
#-------------------------------------------------------------------#


#-------------------------------------------------------------------#
# ($ns, $prefix, $lname) = $self->_get_ns_details($qname, $f_attr)
# returns ns, prefix, and lname for a given attribute name
# >> the $f_attr flag, if set to one, will work for an attribute
#-------------------------------------------------------------------#
sub _get_ns_details {
    my $self    = shift;
    my $qname   = shift;
    my $aflag   = shift;

    my ($ns, $prefix, $lname);
    (my ($tmp_prefix, $tmp_lname) = split /:/, $qname, 3)
                                    < 3 or die "Invalid QName: $qname";

    # no prefix
    if (not defined($tmp_lname)) {
        $prefix = undef;
        $lname = $qname;
        # attr don't have a default namespace
        $ns = ($aflag) ? undef : $self->{nsmap}->[-1]->{default};
    }

    # prefix
    else {
        if (exists $self->{nsmap}->[-1]->{prefix_map}->{$tmp_prefix}) {
            $prefix = $tmp_prefix;
            $lname  = $tmp_lname;
            $ns     = $self->{nsmap}->[-1]->{prefix_map}->{$prefix}
        }
        else { # no ns -> lname == name, all rest undef
            die "Undeclared prefix: $tmp_prefix";
        }
    }

    return ($ns, $prefix, $lname);
}
#-------------------------------------------------------------------#

#-------------------------------------------------------------------#
# parse_jclark_notation() - parse the Clarkian notation
#-------------------------------------------------------------------#
sub parse_jclark_notation {
    shift;
    my $jc = shift;
    $jc =~ m/^\{(.*)\}([^}]+)$/;
    return $1, $2;
}
#-------------------------------------------------------------------#


#-------------------------------------------------------------------#
# Java names mapping
#-------------------------------------------------------------------#
*XML::NamespaceSupport::pushContext          = \&push_context;
*XML::NamespaceSupport::popContext           = \&pop_context;
*XML::NamespaceSupport::declarePrefix        = \&declare_prefix;
*XML::NamespaceSupport::declarePrefixes      = \&declare_prefixes;
*XML::NamespaceSupport::getPrefix            = \&get_prefix;
*XML::NamespaceSupport::getPrefixes          = \&get_prefixes;
*XML::NamespaceSupport::getDeclaredPrefixes  = \&get_declared_prefixes;
*XML::NamespaceSupport::getURI               = \&get_uri;
*XML::NamespaceSupport::processName          = \&process_name;
*XML::NamespaceSupport::processElementName   = \&process_element_name;
*XML::NamespaceSupport::processAttributeName = \&process_attribute_name;
*XML::NamespaceSupport::parseJClarkNotation  = \&parse_jclark_notation;
#-------------------------------------------------------------------#


1;
#,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,#
#`,`, Documentation `,`,`,`,`,`,`,`,`,`,`,`,`,`,`,`,`,`,`,`,`,`,`,`,#
#```````````````````````````````````````````````````````````````````#

=pod

=head1 NAME

XML::NamespaceSupport - a simple generic namespace support class

=head1 SYNOPSIS

  use XML::NamespaceSupport;
  my $nsup = XML::NamespaceSupport->new;

  # add a new empty context
  $nsup->push_context;
  # declare a few prefixes
  $nsup->declare_prefix($prefix1, $uri1);
  $nsup->declare_prefix($prefix2, $uri2);
  # the same shorter
  $nsup->declare_prefixes($prefix1 => $uri1, $prefix2 => $uri2);

  # get a single prefix for a URI (randomly)
  $prefix = $nsup->get_prefix($uri);
  # get all prefixes for a URI (probably better)
  @prefixes = $nsup->get_prefixes($uri);
  # get all prefixes in scope
  @prefixes = $nsup->get_prefixes();
  # get all prefixes that were declared for the current scope
  @prefixes = $nsup->get_declared_prefixes;
  # get a URI for a given prefix
  $uri = $nsup->get_uri($prefix);

  # get info on a qname (java-ish way, it's a bit weird)
  ($ns_uri, $local_name, $qname) = $nsup->process_name($qname, $is_attr);
  # the same, more perlish
  ($ns_uri, $prefix, $local_name) = $nsup->process_element_name($qname);
  ($ns_uri, $prefix, $local_name) = $nsup->process_attribute_name($qname);

  # remove the current context
  $nsup->pop_context;

  # reset the object for reuse in another document
  $nsup->reset;

  # a simple helper to process Clarkian Notation
  my ($ns, $lname) = $nsup->parse_jclark_notation('{http://foo}bar');
  # or (given that it doesn't care about the object
  my ($ns, $lname) = XML::NamespaceSupport->parse_jclark_notation('{http://foo}bar');


=head1 DESCRIPTION

This module offers a simple to process namespaced XML names (unames)
from within any application that may need them. It also helps maintain
a prefix to namespace URI map, and provides a number of basic checks.

The model for this module is SAX2's NamespaceSupport class, readable at
http://www.megginson.com/SAX/Java/javadoc/org/xml/sax/helpers/NamespaceSupport.html.
It adds a few perlisations where we thought it appropriate.

=head1 METHODS

=over 4

=item * XML::NamespaceSupport->new(\%options)

A simple constructor.

The options are C<xmlns> and C<fatal_errors>.

If C<xmlns> is turned on (it is off by default) the mapping from the
xmlns prefix to the URI defined for it in DOM level 2 is added to the
list of predefined mappings (which normally only contains the xml
prefix mapping).

If C<fatal_errors> is turned off (it is on by default) a number of
validity errors will simply be flagged as failures, instead of
die()ing.

=item * $nsup->push_context

Adds a new empty context to the stack. You can then populate it with
new prefixes defined at this level.

=item * $nsup->pop_context

Removes the topmost context in the stack and reverts to the previous
one. It will die() if you try to pop more than you have pushed.

=item * $nsup->declare_prefix($prefix, $uri)

Declares a mapping of $prefix to $uri, at the current level.

=item * $nsup->declare_prefixes(%prefixes2uris)

Declares a mapping of several prefixes to URIs, at the current level.

=item * $nsup->get_prefix($uri)

Returns a prefix given an URI. Note that as several prefixes may be
mapped to the same URI, it returns an arbitrary one. It'll return
undef on failure.

=item * $nsup->get_prefixes($uri)

Returns an array of prefixes given an URI. It'll return all the
prefixes if the uri is undef.

=item * $nsup->get_declared_prefixes

Returns an array of all the prefixes that have been declared within
this context, ie those that were declared on the last element, not
those that were declared above and are simply in scope.

=item * $nsup->get_uri($prefix)

Returns a URI for a given prefix. Returns undef on failure.

=item * $nsup->process_name($qname, $is_attr)

Given a qualified name and a boolean indicating whether this is an
attribute or another type of name (those are differently affected by
default namespaces), it returns a namespace URI, local name, qualified
name tuple. I know that that is a rather abnormal list to return, but
it is so for compatibility with the Java spec. See below for more
Perlish alternatives.

If the prefix is not declared, or if the name is not valid, it'll
either die or return undef depending on the current setting of
C<fatal_errors>.

=item * $nsup->process_element_name($qname)

Given a qualified name, it returns a namespace URI, prefix, and local
name tuple. This method applies to element names.

If the prefix is not declared, or if the name is not valid, it'll
either die or return undef depending on the current setting of
C<fatal_errors>.

=item * $nsup->process_attribute_name($qname)

Given a qualified name, it returns a namespace URI, prefix, and local
name tuple. This method applies to attribute names.

If the prefix is not declared, or if the name is not valid, it'll
either die or return undef depending on the current setting of
C<fatal_errors>.

=item * $nsup->reset

Resets the object so that it can be reused on another document.

=back

All methods of the interface have an alias that is the name used in
the original Java specification. You can use either name
interchangeably. Here is the mapping:

  Java name                 Perl name
  ---------------------------------------------------
  pushContext               push_context
  popContext                pop_context
  declarePrefix             declare_prefix
  declarePrefixes           declare_prefixes
  getPrefix                 get_prefix
  getPrefixes               get_prefixes
  getDeclaredPrefixes       get_declared_prefixes
  getURI                    get_uri
  processName               process_name
  processElementName        process_element_name
  processAttributeName      process_attribute_name

=head1 TODO

 - add more tests
 - optimise here and there

=head1 AUTHOR

Robin Berjon, robin@knowscape.com, with lots of it having been done
by Duncan Cameron, and a number of suggestions from the perl-xml
list.

=head1 COPYRIGHT

Copyright (c) 2001 Robin Berjon. All rights reserved. This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=head1 SEE ALSO

XML::Parser::PerlSAX

=cut
