use strict;

my $g_trade_url;
my $g_vendor_url;
my $g_set_vendor;
my $g_set_offer_product;
my $g_set_accept_product;
my $g_set_product_offer_by_vendor;
my $g_set_product_accept_by_vendor;
my $g_error;

sub vendor_url
	{
	my $vendor = shift;
	my $url = shift;

	$g_vendor_url->{$vendor} = $url;
	return;
	}

sub vendor_offer
	{
	my $vendor = shift;
	my $product = shift;

	$g_set_vendor->{$vendor} = 1;
	$g_set_offer_product->{$product} = 1;
	$g_set_product_offer_by_vendor->{$product}->{$vendor} = 1;
	}

sub vendor_accept
	{
	my $vendor = shift;
	my $product = shift;

	$g_set_vendor->{$vendor} = 1;
	$g_set_accept_product->{$product} = 1;
	$g_set_product_accept_by_vendor->{$product}->{$vendor} = 1;
	}

sub vendor_trade_url
	{
	my $vendor = shift;
	my $offer = shift;
	my $accept = shift;
	my $url = shift;

	$g_trade_url->{$vendor}->{$offer}->{$accept} = $url;
	return;
	}

sub vendors_who_offer
	{
	my $product = shift;

	return
	[sort_names(keys %{$g_set_product_offer_by_vendor->{$product}})];
	}

sub vendors_who_accept
	{
	my $product = shift;

	return
	[sort_names(keys %{$g_set_product_accept_by_vendor->{$product}})];
	}

sub page_trade_read_data
	{
	my $text = shift;

	# If we've already read the data, don't read it again.
	return if defined $g_vendor_url;

	$g_vendor_url = {};
	$g_trade_url = {};
	$g_set_vendor = {}; # LATER not used yet

	$g_set_accept_product = {};
	$g_set_offer_product = {};

	$g_set_product_accept_by_vendor = {};
	$g_set_product_offer_by_vendor = {};

	$g_error = 0;

	my $pos = 0;
	while (1)
		{
		my $token = token_get($text,$pos);
		last if !defined $token;

		if ($token eq "vendor_url")
			{
			my $vendor = token_get($text,$pos);
			my $url = token_get($text,$pos);
			last if !defined $url;
			vendor_url($vendor,$url);
			}
		elsif ($token eq "vendor_offer")
			{
			my $vendor = token_get($text,$pos);
			my $product = token_get($text,$pos);
			last if !defined $product;
			vendor_offer($vendor,$product);
			}
		elsif ($token eq "vendor_accept")
			{
			my $vendor = token_get($text,$pos);
			my $product = token_get($text,$pos);
			last if !defined $product;
			vendor_accept($vendor,$product);
			}
		elsif ($token eq "vendor_trade_url")
			{
			my $vendor = token_get($text,$pos);
			my $offer = token_get($text,$pos);
			my $accept = token_get($text,$pos);
			my $url = token_get($text,$pos);
			last if !defined $url;
			vendor_trade_url($vendor,$offer,$accept,$url);
			}
		else
			{
			$g_error = 1;
			}
		}

	if ($g_error)
		{
		emit(<<EOM
<div class=alarm> Internal page error </div>
EOM
);
		}

	return;
	}

sub page_trade_search
	{
	my $payload = shift;
	page_trade_read_data($payload);

	my $offer_product = http_get("offer");
	my $accept_product = http_get("accept");

	emit(<<EOM
<p>
Click an item in each column.  As you click, entries will highlight in gold to
reflect new possibilities.

<p>
<table border=1 cellpadding=2 style='border-collapse:collapse;'>
<colgroup>
<col width=215>
<col width=215>
<col width=215>
</colgroup>
<tr>
EOM
);

	my $warm_color = "#fff7b5";

	for my $type (qw(offer accept))
		{
		my $table = "";

		my $label = $type eq "offer"
			? "You seek:"
			: "in exchange for:";

		$table .= <<EOM;
<h2> $label </h2>
<table border=0 cellpadding=2 style='border-collapse:collapse;'>
EOM
		my @products;
		if ($type eq "offer")
			{
			@products = keys %{$g_set_offer_product};
			}
		elsif ($type eq "accept")
			{
			@products = keys %{$g_set_accept_product};
			}

		@products = sort_names(@products);

		for my $product (@products)
			{
			my $highlight = 0;
			if ($type eq "offer" && $product eq $offer_product)
				{
				$highlight = 1;
				}
			elsif ($type eq "accept" && $product eq $accept_product)
				{
				$highlight = 1;
				}

			my $style = $highlight ? " class=highlight_link" : "";

			my $context = op_new
				(
				"offer",$offer_product,
				"accept",$accept_product,
				);

			op_put($context,$type,$product);

			my $url = make_url("/trade",op_pairs($context));

			my $q_product = html_semiquote($product);
			$q_product = qq{<a$style href="$url">$q_product</a>};

			my $possible = 0;
			if ($type eq "offer" && $accept_product ne "")
				{
				my $vendors = intersect(
					vendors_who_offer($product),
					vendors_who_accept($accept_product));
				$possible = (@$vendors > 0);
				}
			elsif ($type eq "accept" && $offer_product ne "")
				{
				my $vendors = intersect(
					vendors_who_offer($offer_product),
					vendors_who_accept($product));
				$possible = (@$vendors > 0);
				}

			my $cell_style = $possible
				? " style='background-color:$warm_color'" : "";

			$table .= <<EOM;
<tr>
<td$cell_style> $q_product </td>
</tr>
EOM
			}
		$table .= <<EOM;
</table>
EOM
		emit(<<EOM
<td valign=top>
$table
</td>
EOM
);
		}

	my $vendors = intersect(
		vendors_who_offer($offer_product),
		vendors_who_accept($accept_product));

	my $table .= <<EOM;
<table border=0 cellpadding=2 style='border-collapse:collapse;'>
EOM
	for my $vendor (@$vendors)
		{
		my $q_vendor = html_semiquote($vendor);

		my $url;
		if ($offer_product ne "" && $accept_product ne "")
			{
			$url =
			$g_trade_url->{$vendor}->{$offer_product}->{$accept_product};
			}

		$url = $g_vendor_url->{$vendor} if !defined $url;

		$q_vendor = qq{<a href="$url">$q_vendor</a>} if defined $url;

		$table .= <<EOM;
<tr>
<td> $q_vendor </td>
</tr>
EOM
		}
	$table .= <<EOM;
</table>
EOM

	emit(<<EOM
<td valign=top>
<h2> Possible vendors: </h2>
$table
</td>
EOM
);

	emit(<<EOM
</tr>
</table>
EOM
);

	return;
	}

sub page_trade_get_listed
	{
	emit(<<EOM
<p>
To obtain a listing on the Find Trades page, we ask that you
<a href="http://rayservers.com/gold">get verified by the GSF System</a>.
Verification by this trusted party helps people do business safely.
Otherwise, you're on your own.
EOM
);

	return;
	}

sub page_trade_respond
	{
	my $id = shift;
	my $header_op = shift;
	my $payload = shift;

	top_link(highlight_link("/","Home",0));

	my $query = http_get("q");

	top_link(highlight_link("/trade","Find Trades",($query eq "")));
	top_link(highlight_link("/trade?q=get-listed",
		"Get Listed Here",($query eq "get-listed")));

	if ($query eq "")
		{
		set_title("Find Trades");
		page_trade_search($payload);
		}
	elsif ($query eq "get-listed")
		{
		set_title("Get Listed");
		page_trade_get_listed();
		}
	else
		{
		page_not_found();
		}

	return;
	}

return 1;
