package Loom::DB::Trans;
use strict;

=pod

=head1 NAME

Transaction buffer:  convert get/update to get/put/commit/cancel

=head1 DESCRIPTION

This module converts a get/update object into a get/put/commit/cancel object.
Examples of get/update objects are Loom::DB::File or Loom::DB::Mem.

=cut

sub new
	{
	my $class = shift;
	my $db = shift;

	my $s = bless({},$class);
	$s->{db} = $db;
	$s->cancel;
	return $s;
	}

# LATER 0331 experimenting with monitoring size in web transactions

sub get
	{
	my $s = shift;
	my $key = shift;

	return "" if !defined $key;

	my $val = $s->{new_val}->{$key};
	return $val if defined $val;

	$val = $s->{old_val}->{$key};
	return $val if defined $val;

	$val = $s->{db}->get($key);

	$s->{old_val}->{$key} = $val;
	$s->{size} += length($val) if defined $val;
	return $val;
	}

sub put
	{
	my $s = shift;
	my $key = shift;
	my $val = shift;

	return if !defined $key || ref($key) ne "";
	$val = "" if !defined $val;

	my $old_len = 0;
	$old_len = length($s->{new_val}->{$key}) if defined $s->{new_val}->{$key};

	$val = "".$val; # prepend null to force numbers to be stored as strings
	$s->{new_val}->{$key} = $val;

	$s->{size} += length($val) - $old_len;
	return;
	}

sub size
	{
	my $s = shift;
	return $s->{size};
	}

sub commit
	{
	my $s = shift;

	my $ok = $s->{db}->update($s->{new_val},$s->{old_val});
	$s->cancel;
	return $ok;
	}

sub cancel
	{
	my $s = shift;

	$s->{old_val} = {};
	$s->{new_val} = {};
	$s->{size} = 0;
	return;
	}

return 1;

__END__

# Copyright 2009 Patrick Chkoreff
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions
# and limitations under the License.
