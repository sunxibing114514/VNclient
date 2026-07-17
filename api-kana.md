
# Introduction

This document describes the HTTPS API to query information from the
[VNDB](https://vndb.org/) database and manage user lists.

This version of the API replaces the [old TCP-based
API](https://api.vndb.org/nyan).

**API endpoint**: `%endpoint%`

A sandbox endpoint is available for testing and development at
[https://beta.vndb.org/api/kana](https://beta.vndb.org/api/kana), for more
information see [the sandbox](https://beta.vndb.org/about-sandbox).

# Usage Terms

This service is free for non-commercial use. The API is provided on a
best-effort basis, no guarantees are made about the stability or applicability
of this service.

The data obtained through this API is subject to our [Data
License](https://vndb.org/d17#4).

API access is rate-limited in order to keep server resources in check. The
server will allow up to 200 requests per 5 minutes and up to 1 second of
execution time per minute. Requests taking longer than 3 seconds will be
aborted. These limits should be more than enough for most applications, but if
this is still too limiting for you, don't hesitate to get in touch.

This API intentionally does not expose *all* functionality provided by VNDB.
Some site features, such as forums, database editing or account creation will
not be exposed through the API, other features may be missing simply because
nobody has asked for it yet. If you need anything not yet provided by the API
or if you have any other questions, feel free to post on [the
forums](https://vndb.org/t/db), [the issue
tracker](https://code.blicky.net/yorhel/vndb/issues) or mail
[contact@vndb.org](mailto:contact@vndb.org).


# Common Data Types

vndbid
:   A 'vndbid' is an identifier for an entry in the database, typically
    formatted as a number with a one or two character prefix, e.g. "v17" refers
    to [this visual novel](https://vndb.org/v17) and "sf190" refers to [this
    screenshot](https://vndb.org/img/sf190).
:   The API will return vndbids as a JSON string, but the filters also accept
    bare integers if the prefix is unambiguous from the context.

release date
:   Release dates are represented as JSON strings as either `"YYYY-MM-DD"`,
    `"YYYY-MM"` or `"YYYY"` formats, depending on whether the day and month are
    known. Unspecified future dates are returned as `"TBA"`. The values
    `"unknown"` and `"today"` are also supported in filters.
:   Partial dates are ordered *after* complete dates for the same year/month,
    i.e. `"2022"` is ordered after `"2022-12"`, which in turn is ordered after
    `"2022-12-31"`. This can be unintuitive when writing filters: `["released",
    "<", "2022-01"]` also matches all complete dates in Jan 2022. Likewise,
    `["released", "=", "2022"]` only matches items for which the release date
    is exactly `"2022"`, not any other date in that year.

enumeration types
:   Several fields in the database are represented as an integer or string with
    a limited number of possible values. These values are either documented for
    the particular field or listed separately in the [schema JSON](#get-schema).


# User Authentication

The majority of the API endpoints below are usable without any form of
authentication, but some user-related actions - in particular, list management
- require the calls to be authenticated with the respective VNDB user account.

The API understands cookies originating from the main `vndb.org` domain, so
user scripts running from the site only have to ensure that
[XMLHttpRequest.withCredentials](https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest/withCredentials)
or [the Fetch API "credentials"
parameter](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#sending_a_request_with_credentials_included)
is set.

In all other cases, token authentication should to be used. Users can obtain a
token by opening their "My Profile" form and going to the "Applications" tab.
The URL `https://vndb.org/u/tokens` can also be used to redirect users to this
form.  Tokens look like `xxxx-xxxxx-xxxxx-xxxx-xxxxx-xxxxx-xxxx`, with each `x`
representing a lowercase z-base-32 character. The dashes in between are
optional.

Tokens may be included in API requests using the `Authorization` header with
the `Token` type, for example:

```
Authorization: Token hsoo-ybws4-j8yb9-qxkw-5obay-px8to-bfyk
```

A HTTP 401 error is returned if the token is invalid. The [GET
/authinfo](#get-authinfo) endpoint can be used validate and extract information
from tokens.


# Simple Requests

## GET /schema

Returns a [JSON object](%endpoint%/schema) with metadata about several API
objects, including enumeration values, which fields are available for querying
and a list of supported external links. The JSON structure is hopefully
self-explanatory.

This information does not change very often and can safely be used for code
generation or dynamic API introspection.

The `url_format` attribute of external links is purely informational and should
not be used to construct URLs. The API has custom URL formatting rules for
various sites that may not match this `url_format`.

## GET /stats

Returns a few overall database statistics.

`curl %endpoint%/stats`

```json
{
  "chars": 112347,
  "producers": 14789,
  "releases": 91490,
  "staff": 27929,
  "tags": 2783,
  "traits": 3115,
  "vn": 36880
}
```

## GET /user

Lookup users by id or username. Accepts two query parameters:

q
:   User ID or username to look up, can be given multiple times to look up
    multiple users.

fields
:   List of fields to select. The 'id' and 'username' fields are always
    selected and should not be specified here.

The response object contains one key for each given `q` parameter, its value is
either `null` if no such user was found or otherwise an object with the
following fields:

id
:   String in `"u123"` format.

username
:   String.

lengthvotes
:   Integer, number of play time votes this user has submitted.

lengthvotes\_sum
:   Integer, sum of the user's play time votes, in minutes.

Strings that look like user IDs are not valid usernames, so the lookup is
unambiguous. Usernames matching is case-insensitive.

`curl '%endpoint%/user?q=NoUserWithThisNameExists&q=AYO&q=u3'`

```json
{
  "AYO": {
    "id": "u3",
    "username": "ayo"
  },
  "NoUserWithThisNameExists": null,
  "u3": {
    "id": "u3",
    "username": "ayo"
  }
}
```

`curl '%endpoint%/user?q=yorhel&fields=lengthvotes,lengthvotes_sum'`

```json
{
  "yorhel": {
    "id": "u2",
    "lengthvotes": 9,
    "lengthvotes_sum": 9685,
    "username": "Yorhel"
  }
}
```

## GET /authinfo

Validates and returns information about the given [API
token](#user-authentication). The JSON object has the following members:

id
:   String, user ID.

username
:   String, username.

permissions
:   Array of strings, permissions granted to this token.

The following permissions are currently implemented:

listread
:   Allows read access to private labels and entries in the user's visual novel
    list.

listwrite
:   Allows write access to the user's visual novel list.

```sh
curl %endpoint%/authinfo\
    --header 'Authorization: token cdhy-bqy1q-6zobu-8w9k-xobxh-wzz4o-84fn'
```

```json
{
  "id": "u3",
  "username": "ayo",
  "permissions": [
    "listread"
  ]
}
```


# Database Querying

## API Structure

Searching for and fetching database entries is done through a custom query
format^[Yes, sorry, I know every API having its own query system sucks, but I
couldn't find an existing solution that works well for VNDB.]. Queries are sent
as `POST` requests, but I expect to also support the `QUERY` HTTP method once
that gains more software support.

### Query format

A query is a JSON object that looks like this:

```json
{
  "filters": [],
  "fields": "",
  "sort": "id",
  "reverse": false,
  "results": 10,
  "page": 1,
  "user": null,
  "count": false,
  "compact_filters": false,
  "normalized_filters": false
}
```

All members are optional, defaults are shown above.

filters
:   Filters are used to determine which database items to fetch, see the
    section on [Filters](#filters) below.

fields
:   String. Comma-separated list of fields to fetch for each database item. Dot
    notation can be used to select nested JSON objects, e.g. `"image.url"` will
    select the `url` field inside the `image` object. Multiple nested fields
    can be selected with brackets, e.g. `"image{id,url,dims}"` is equivalent to
    `"image.id, image.url, image.dims"`.
:   Every field of interest must be explicitely mentioned, there is no support
    for wildcard matching. The same applies to nested objects, it is an error
    to list `image` without sub-fields in the example above.
:   The top-level `id` field is always selected by default and does not have to
    be mentioned in this list.

sort
:   Field to sort on. Supported values depend on the type of data being queried
    and are documented separately.

reverse
:   Set to true to sort in descending order.

results
:   Number of results per page, max 100. Can also be set to `0` if you're not
    interested in the results at all, but just want to verify your query or get
    the `count`, `compact_filters` or `normalized_filters`.

page
:   Page number to request, starting from 1. See also the [note on
    pagination](#pagination) below.

user
:   User ID. This field is mainly used for `POST /ulist`, but it also
    sets the default user ID to use for the visual novel "label" filter.
    Defaults to the currently authenticated user.

count
:   Whether the response should include the `count` field (see below). This
    option should be avoided when the count is not needed since it has a
    considerable performance impact.

compact\_filters
:   Whether the response should include the `compact_filters` field (see below).

normalized\_filters
:   Whether the response should include the `normalized_filters` field (see below).


### Response format

```json
{
  "results": [],
  "more": false,
  "count": 1,
  "compact_filters": "",
  "normalized_filters": [],
}
```

results
:   Array of objects representing the query results.

more
:   When `true`, repeating the query with an incremented `page` number will
    yield more results. This is a cheaper form of pagination than using the
    `count` field.

count
:   Only present if the query contained `"count":true`. Indicates the total
    number of entries that matched the given filters.

compact\_filters
:   Only present if the query contained `"compact_filters":true`. This is a
    compact string representation of the filters given in the query.

normalized\_filters
:   Only present if the query contained `"normalized_filters":true`. This is
    a normalized JSON representation of the filters given in the query.

### Filters

Simple predicates are represented as a three-element JSON array containing a
filter name, operator and value, e.g. `[ "id", "=", "v17" ]`. All filters
accept the (in)equality operators `=` and `!=`. Filters that support ordering
also accept `>=`, `>`, `<=` and `<`.  The full list of accepted filter names
and values is documented below for each type of database item.

Simple predicates can be combined into larger queries with and/or predicates.
These are represented as JSON arrays where the first element is either `"and"`
or `"or"`, followed by two or more other predicates.

Full example of a more complex visual novel filter (which, as of writing,
doesn't actually match anything in the database):

```json
[ "and"
, [ "or"
  , [ "lang", "=", "en" ]
  , [ "lang", "=", "de" ]
  , [ "lang", "=", "fr" ]
  ]
, [ "olang", "!=", "ja" ]
, [ "release", "=", [ "and"
    , [ "released", ">=", "2020-01-01" ]
    , [ "producer", "=", [ "id", "=", "p30" ] ]
    ]
  ]
]
```

Besides the above JSON format, filters can also be represented as a more
compact string. This representation is used in the URLs for the advanced search
web interface^[Fun fact: the web interface also accepts filters in JSON form,
but that tends to result in long and ugly URLs.] and is also accepted as value
to the `"filters"` field. Since actually working with the compact string
representation is kind of annoying, this API can convert between the two
representations, so you can freely copy filters from the website to the API and
the other way around.^[There is also a third representation for filters, which
the API also accepts, but I won't bother you with that. It's only useful as an
intermediate representation when converting between the JSON and string format,
which you shouldn't be doing manually.]

The compact representation of the above example is
`"03132gen2gde2gfr3hjaN180272_0c2vQN6830u"` and can be seen in action in [the web
UI](https://vndb.org/v?f=03132gen2gde2gfr3hjaN180272_0c2vQN6830u). The following
command will convert that string back into the above JSON:

```sh
curl %endpoint%/vn --header 'Content-Type: application/json' --data '{
    "filters": "03132gen2gde2gfr3hjaN180272_0c2vQN6830u",
    "normalized_filters": true
}'
```

Note that the advanced search editing UI on the site does not support all
filter types, for unsupported filters you will see an "Unrecognized filter"
block.  These are pretty harmless, the filter still works.

#### Filter flags

These flags are used in the documentation below to describe a few common filter
properties.

------------------------------------------------------------------------
 Flag  Description
-----  -----------------------------------------------------------------
    o  Ordering operators (such as `>` and `<`) can be used with this filter.

    n  This filter accepts `null` as value.

    m  A single entry can match multiple values. For example, a visual novel
       available in both English and Japanese matches both `["lang","=","en"]`
       and `["lang","=","ja"]`.

    i  Inverting or negating this filter (e.g. by changing the operator from
       '=' to '!=' or from '>' to '<=') is not always equivalent to inverting
       the selection of matching entries. This often means that the filter
       implies another requirement (e.g. that the information must be known in
       the first place), but the exact details depend on the filter.
------------------------------------------------------------------------

Be careful with applying boolean algebra to filters with the 'm' or 'i' flags,
the results may be unintuitive. For example, searching for releases matching
`["or",["minage","=",0],["minage","!=",0]]` will **not** find all releases in
the database, but only those for which the `minage` field is known. Exact
semantics regarding unknown or missing information often depends on how the
filter is implemented and may be subject to change.

## POST /vn

Query visual novel entries.

```sh
curl %endpoint%/vn --header 'Content-Type: application/json' --data '{
    "filters": ["id", "=", "v17"],
    "fields": "title, image.url"
}'
```

Accepted values for `"sort"`: `id`, `title`, `released`, `rating`, `votecount`, `searchrank`.

### Filters {#vn-filters}

-----------------------------------------------------------------------------
Name              [F]  Description
----------------  ---- -------------------------------------------------------
`id`              o    vndbid

`search`          m    String search, matches on the VN titles, aliases and release titles.
                       The search algorithm is the same as used on the site.

`lang`            m    Language availability.

`olang`                Original language.

`platform`        m    Platform availability.

`length`          o    Play time estimate, integer between 1 (Very short) and 5 (Very long).
                       This filter uses the length votes average when available but
                       falls back to the entries' `length` field when there are no votes.

`released`        o,n  Release date.

`rating`          o,i  Bayesian rating, integer between 10 and 100.

`votecount`       o    Integer, number of votes.

`has_description`      Only accepts a single value, integer `1`.
                       Can of course still be negated with the `!=` operator.

`has_anime`            See `has_description`.

`has_screenshot`       See `has_description`.

`has_review`           See `has_description`.

`devstatus`            Development status, integer. See `devstatus` field.

`tag`             m    Tags applied to this VN, also matches parent tags. See below for more details.

`dtag`            m    Tags applied directly to this VN, does not match parent tags. See below for details.

`anime_id`             Integer, AniDB anime identifier.

`label`           m    User labels applied to this VN. Accepts a two-element
                       array containing a user ID and label ID. When
                       authenticated or if the `"user"` request parameter has
                       been set, then it also accepts just a label ID.

`release`         m    Match visual novels that have at least one release
                       matching the given [release filters](#release-filters).

`character`       m    Match visual novels that have at least one character
                       matching the given [character filters](#character-filters).

`staff`           m    Match visual novels that have at least one staff member
                       matching the given [staff filters](#staff-filters).

`developer`       m    Match visual novels developed by the given [producer filters](#producer-filters).
------------------------------------------------------------------------------

The `tag` and `dtag` filters accept either a plain tag ID or a three-element
array containing the tag ID, maximum spoiler level (0, 1 or 2) and minimum tag
level (number between 0 and 3, inclusive), for example
`["tag","=",["g505",2,1.2]]` matches all visual novels that have a [Donkan
Protagonist](https://vndb.org/g505) with a vote of at least 1.2 at any spoiler
level. If only an ID is given, `0` is assumed for both the spoiler and tag
levels. For example, `["tag","=","g505"]` is equivalent to
`["tag","=",["g505",0,0]]`.

### Fields {#vn-fields}

id
:   vndbid.

title
:   String, main title as displayed on the site, typically romanized from the
    original script.

alttitle
:   String, can be null. Alternative title, typically the same as `title` but
    in the original script.

titles
:   Array of objects, full list of titles associated with the VN, always
    contains at least one title.

titles.lang
:   String, language. Each language appears at most once in the titles list.

titles.title
:   String, title in the original script.

titles.latin
:   String, can be null, romanized version of `title`.

titles.official
:   Boolean.

titles.main
:   Boolean, whether this is the "main" title for the visual novel entry.
    Exactly one title has this flag set in the `titles` array and it's always
    the title whose `lang` matches the VN's `olang` field. This field is
    included for convenience, you can of course also use the `olang` field to
    grab the main title.

aliases
:   Array of strings, list of aliases.

olang
:   String, language the VN has originally been written in.

devstatus
:   Integer, development status. 0 meaning 'Finished', 1 is 'In development'
    and 2 for 'Cancelled'.

released
:   Release date, possibly null.

languages
:   Array of strings, list of languages this VN is available in. Does not
    include machine translations.

platforms
:   Array of strings, list of platforms for which this VN is available.

image
:   Object, can be null.

image.id
:   String, image identifier.

image.url
:   String.

image.dims
:   Pixel dimensions of the image, array with two integer elements indicating
    the width and height.

image.sexual
:   Number between 0 and 2 (inclusive), average image flagging vote for sexual
    content.

image.violence
:   Number between 0 and 2 (inclusive), average image flagging vote for violence.

image.votecount
:   Integer, number of image flagging votes.

image.thumbnail
:   String, URL to the thumbnail.

image.thumbnail\_dims
:   Pixel dimensions of the thumbnail, array with two integer elements.

length
:   Integer, possibly null, rough length estimate of the VN between 1 (very
    short) and 5 (very long). This field is only used as a fallback for when
    there are no length votes, so you'll probably want to fetch
    `length_minutes` too.

length\_minutes
:   Integer, possibly null, average of user-submitted play times in minutes.

length\_votes
:   Integer, number of submitted play times.

description
:   String, possibly null, may contain [formatting codes](https://vndb.org/d9#4).

average
:   Raw vote average, between 10 and 100, null if nobody voted (cached, may be
    out of date by an hour).

rating
:   Bayesian rating, between 10 and 100, null if nobody voted (cached).

votecount
:   Integer, number of votes (cached).

screenshots
:   Array of objects, possibly empty.

screenshots.\*
:   The above `image.*` fields are also available for screenshots.

screenshots.release.\*
:   Release object. All [release fields](#release-fields) can be selected. It
    is very common for all screenshots of a VN to be assigned to the same
    release, so the fields you select here are likely to get duplicated several
    times in the response. If you want to fetch more than just a few fields, it
    is more efficient to only select `release.id` here and then grab detailed
    release info with a separate request.

relations
:   Array of objects, list of VNs directly related to this entry.

relations.relation
:   String, relation type.

relations.relation\_official
:   Boolean, whether this VN relation is official.

relations.\*
:   All [visual novel fields](#vn-fields) can be selected here.

tags
:   Array of objects, possibly empty. Only directly applied tags are returned,
    parent tags are not included.

tags.rating
:   Number, tag rating between 0 (exclusive) and 3 (inclusive).

tags.spoiler
:   Integer, 0, 1 or 2, spoiler level.

tags.lie
:   Boolean.

tags.\*
:   All [tag fields](#tag-fields) can be used here. If you're fetching tags for
    more than a single visual novel, it's usually more efficient to only select
    `tags.id` here and then fetch (and cache) further tag information as a
    separate request. Otherwise the same tag info may get duplicated many times
    in the response.

developers
:   Array of objects. The developers of a VN are all producers with a
    "developer" role on a release linked to the VN. You can get this same
    information by fetching all relevant release entries, but if all you need
    is the list of developers then querying this field is faster.

developers.\*
:   All [producer fields](#producer-fields) can be used here.

editions
:   Array of objects, possibly empty.

editions.eid
:   Integer, edition identifier. This identifier is local to the
    visual novel and not stable across edits of the VN entry, it's only used
    for organizing the staff listing (see below) and has no meaning beyond
    that. But this is subject to change in the future.

editions.lang
:   String, possibly null, language.

editions.name
:   String, English name / label identifying this edition.

editions.official
:   Boolean.

staff
:   Array of objects, possibly empty.

staff.eid
:   Integer, edition identifier or *null* when the staff has worked on the
    "original" version of the visual novel.

staff.role
:   String, see `enums.staff_role` in the [schema JSON](#get-schema) for
    possible values.

staff.note
:   String, possibly null.

staff.*
:   All [staff fields](#staff-fields) can be used here.

va
:   Array of objects, possibly empty. Each object represents a voice actor
    relation. The same voice actor may be listed multiple times for different
    characters and the same character may be listed multiple times if it has
    been voiced by several people.

va.note
:   String, possibly null.

va.staff.*
:   Person who voiced the character, all [staff fields](#staff-fields) can be
    used here.

va.character.*
:   VN character being voiced, all [character fields](#character-fields) can be
    used here.

extlinks
:   Array, links to external websites. Works the same as the 'extlinks'
    [release field](#release-fields).



## POST /release

Accepted values for `"sort"`: `id`, `title`, `released`, `searchrank`.

### Filters {#release-filters}

-----------------------------------------------------------------------------
Name                [F]   Description
------------------  ----  -------------------------------------------------------
`id`                o     vndbid

`search`            m     String search.

`lang`              m     Match on available languages.

`platform`          m     Match on available platforms.

`released`          o     Release date.

`resolution`        o,i   Match on the image resolution, in pixels. Value must
                          be a two-element integer array to which the width and
                          height, respectively, are compared. For example,
                          `["resolution","<=",[640,480]]` matches releases with a
                          resolution smaller than or equal to 640x480.

`resolution_aspect` o,i   Same as the `resolution` filter, but additionally
                          requires that the aspect ratio matches that of the
                          given resolution.

`minage`            o,n,i Integer (0-18), age rating.

`medium`            m,n   String.

`voiced`            n     Integer, see `voiced` field.

`engine`            n     String.

`rtype`             m     String, see `vns.rtype` field. If this filter is used
                          when nested inside a visual novel filter, then this
                          matches the `rtype` of the particular visual novel.
                          Otherwise, this matches the `rtype` of any linked
                          visual novel.

`extlink`           m     Match on external links, see below for details.

`drm`               m     String, match on DRM implementation.

`image`             m,n   String, see `images.type` field.

`patch`                   Integer, only accepts the value `1`.

`freeware`                See `patch`.

`uncensored`        i     See `patch`.

`official`                See `patch`.

`has_ero`                 See `patch`.

`vn`                m     Match releases that are linked to at least one visual novel
                          matching the given [visual novel filters](#vn-filters).

`producer`          m     Match releases that have at least one producer
                          matching the given [producer filters](#producer-filters).
-----------------------------------------------------------------------------

The `extlink` filter can be used with three types of values:

- Just a site name, e.g. `["extlink","=","steam"]` matches all releases that
  have a steam ID.
- A two-element array indicating the site name and the remote identifier, e.g.
  `["extlink","=",["steam",702050]]` to match the Saya no Uta release on Steam.
  The second element can be either an int or a string, depending on the site,
  but integer identifiers are also accepted when formatted as a string.
- A URL, e.g. `["extlink","=","https://store.steampowered.com/app/702050/"]` is
  equivalent to the above example.

In all of the above forms, an error is returned if the site is not known in the
database or if the URL format is not recognized. The list of supported sites
and URL formats tends to change over time, see [GET /schema](#get-schema) for
the current list of supported sites.

*Undocumented: animation*

### Fields {#release-fields}

id
:   vndbid.

title
:   String, main title as displayed on the site, typically romanized from the
    original script.

alttitle
:   String, can be null. Alternative title, typically the same as `title` but
    in the original script.

languages
:   Array of objects, languages this release is available in. There is always
    exactly one language that is considered the "main" language of this
    release, which is only used to select the titles for the `title` and
    `alttitle` fields.

languages.lang
:   String, language. Each language appears at most once.

languages.title
:   String, title in the original script. Can be null, in which case the title
    for this language is the same as the "main" language.

languages.latin
:   String, can be null, romanized version of `title`.

languages.mtl
:   Boolean, whether this is a machine translation.

languages.main
:   Boolean, whether this language is used to determine the "main" title for
    the release entry.

platforms
:   Array of strings.

media
:   Array of objects.

media.medium
:   String.

media.qty
:   Integer, quantity. This is `0` for media where the quantity is unknown or
    where it does not make sense, like "internet download".

vns
:   Array of objects, the list of visual novels this release is linked to.

vns.rtype
:   The release type for this visual novel, can be `"trial"`, `"partial"` or
    `"complete"`.

vns.\*
:   All [visual novel fields](#vn-fields) are available.

producers
:   Array of objects.

producers.developer
:   Boolean.

producers.publisher
:   Boolean.

producers.\*
:   All [producer fields](#producer-fields) are available.

images
:   Array of objects, possibly empty.

images.\*
:   All [visual novel](#vn-fields) `image.*` fields are available here as well.

images.type
:   Image type, valid values are `"pkgfront"`, `"pkgback"`, `"pkgcontent"`,
    `"pkgside"`, `"pkgmed"` and `"dig"`.

images.vn
:   Visual novel ID to which this image applies, usually null. This field is
    only useful for bundle releases that are linked to multiple VNs.

images.languages
:   Array of languages for which this image is valid, or null if the image is
    valid for all languages assigned to this release.

images.photo
:   Boolean.

released
:   Release date.

minage
:   Integer, possibly null, age rating.

patch
:   Boolean.

freeware
:   Boolean.

uncensored
:   Boolean, can be null.

official
:   Boolean.

has\_ero
:   Boolean.

resolution
:   Can either be null, the string `"non-standard"` or an array of two integers
    indicating the width and height.

engine
:   String, possibly null.

voiced
:   Int, possibly null, 1 = not voiced, 2 = only ero scenes voiced, 3 =
    partially voiced, 4 = fully voiced.

notes
:   String, possibly null, may contain [formatting codes](https://vndb.org/d9#4).

gtin
:   JAN/EAN/UPC code, formatted as a string, possibly null.

catalog
:   String, possibly null, catalog number.

extlinks
:   Array, links to external websites. This list is equivalent to the links
    displayed on the release pages on the site, so it may include redundant
    entries (e.g. if a Steam ID is known, links to both Steam and SteamDB are
    included) and links that are automatically fetched from external resources.
    These extra sites are not listed in the `extlinks` list of [the
    schema](#get-schema).

extlinks.url
:   String, URL.

extlinks.label
:   String, English human-readable label for this link.

extlinks.name
:   Internal identifier of the site, intended for applications that want to
    localize the label or to parse/format/extract remote identifiers. Keep in
    mind that the list of supported sites, their internal names and their ID
    types are subject to change, but I'll try to keep things stable.

extlinks.id
:   Remote identifier for this link. Not all sites have a sensible identifier
    as part of their URL format, in such cases this field is simply equivalent
    to the URL.

*Missing: animation.*



## POST /producer

Accepted values for `"sort"`: `id`, `name`, `searchrank`.

### Filters {#producer-filters}

-----------------------------------------------------------------------------
Name                [F]   Description
------------------  ----  -------------------------------------------------------
`id`                o     vndbid

`search`            m     String search.

`lang`                    Language.

`type`                    Producer type, see the `type` field below.

`extlink`           m     Match on external links, works similar to the `extlink`
                          filter for [releases](#release-filters).
-----------------------------------------------------------------------------

### Fields {#producer-fields}

id
:   vndbid.

name
:   String.

original
:   String, possibly null, name in the original script.

aliases
:   Array of strings.

lang
:   String, primary language.

type
:   String, producer type, `"co"` for company, `"in"` for individual and `"ng"`
    for amateur group.

description
:   String, possibly null, may contain [formatting codes](https://vndb.org/d9#4).

extlinks
:   Array, links to external websites. Works the same as the 'extlinks'
    [release field](#release-fields).

*Missing: relations.*


## POST /character

Accepted values for `"sort"`: `id`, `name`, `searchrank`.

### Filters {#character-filters}

-----------------------------------------------------------------------------
Name                [F]   Description
------------------  ----  -------------------------------------------------------
`id`                o     vndbid

`search`            m     String search.

`role`              m     String, see `vns.role` field. If this filter is used
                          when nested inside a visual novel filter, then this
                          matches the `role` of the particular visual novel.
                          Otherwise, this matches the `role` of any linked
                          visual novel.

`blood_type`              String.

`sex`                     String.

`sex_spoil`               String.

`gender`                  String.

`gender_spoil`            String.

`height`            o,n,i Integer, cm.

`weight`            o,n,i Integer, kg.

`bust`              o,n,i Integer, cm.

`waist`             o,n,i Integer, cm.

`hips`              o,n,i Integer, cm.

`cup`               o,n,i String, cup size.

`age`               o,n,i Integer.

`trait`             m     Traits applied to this character, also matches parent
                          traits. See below for more details.

`dtrait`            m     Traits applied directly to this character, does not
                          match parent traits. See below for details.

`birthday`          n     Array of two integers, month and day. Day may be `0`
                          to find characters whose birthday is in a given month.

`seiyuu`            m     Match characters that are voiced by the matching
                          [staff filters](#staff-filters). Voice actor
                          information is actually specific to visual novels,
                          but this filter does not (currently) correlate
                          against the parent entry when nested inside a visual
                          novel filter.

`vn`                m     Match characters linked to visual novels described by
                          [visual novel filters](#vn-filters).
-----------------------------------------------------------------------------

The `trait` and `dtrait` filters accept either a plain trait ID or a
two-element array containing the trait ID and maximum spoiler level. These work
similar to the tag filters for [visual novels](#vn-filters), except that traits
don't have a rating.

### Fields {#character-fields}

id
:   vndbid.

name
:   String.

original
:   String, possibly null, name in the original script.

aliases
:   Array of strings.

description
:   String, possibly null, may contain [formatting codes](https://vndb.org/d9#4).

image.\*
:   Object, possibly null, same sub-fields as the `image` [visual novel field](#vn-fields).
    (Except for `thumbnail` and `thumbnail_dims` because character images are
    currently always limited to 256x300px, but that is subject to change in the
    future).

blood\_type
:   String, possibly null, `"a"`, `"b"`, `"ab"` or `"o"`.

height
:   Integer, possibly null, cm.

weight
:   Integer, possibly null, kg.

bust
:   Integer, possibly null, cm.

waist
:   Integer, possibly null, cm.

hips
:   Integer, possibly null, cm.

cup
:   String, possibly null, `"AAA"`, `"AA"`, or any single letter in the alphabet.

age
:   Integer, possibly null, years.

birthday
:   Possibly null, otherwise an array of two integers: month and day,
    respectively.

sex
:   Possibly null, otherwise an array of two strings: the character's apparent
    (non-spoiler) sex and the character's real (spoiler) sex. Possible values
    are `null`, `"m"`, `"f"`, `"b"` (meaning "both") or `"n"` (sexless).

gender
:   Possibly null, otherwise an array of two strings indicating the character's
    non-spoiler gender and the character's actual (spoiler) gender. Possible
    values are `null`, `"m"`, `"f"`, `"o"` (non-binary) or `"a"` (ambiguous).

vns
:   Array of objects, visual novels this character appears in. The same visual
    novel may be listed multiple times with a different release; the spoiler
    level and role can be different per release.

vns.spoiler
:   Integer.

vns.role
:   String, `"main"` for protagonist, `"primary"` for main characters, `"side"`
    or `"appears"`.

vns.\*
:   All [visual novel fields](#vn-fields) are available here.

vns.release.\*
:   Object, usually null, specific release that this character appears in. All
    [release fields](#release-fields) are available here.

traits
:   Array of objects, possibly empty.

traits.spoiler
:   Integer, 0, 1 or 2, spoiler level.

traits.lie
:   Boolean.

traits.\*
:   All [trait fields](#trait-fields) are available here.

*Missing: gender, instances, voice actor*


## POST /staff

Unlike other database entries, staff have more than one unique identifier.
There is the main 'staff ID', which uniquely identifies a person and is what
a staff page on the site represents.

Additionally, every staff alias also has its own unique identifier, which is
referenced from other database entries to identify which alias was used. This
identifier is generally hidden on the site and aliases do not have their own
page, but the IDs are exposed in this API in order to facilitate linking
VNs/characters to staff names.

This particular API queries staff *names*, not just staff *entries*, which
means that a staff entry with multiple names can be included multiple times in
the API results, once for each name they are known as. When searching or
listing staff entries, this is usually what you want. When fetching more
detailed information about specific staff entries, this is very much not what
you want. The `ismain` filter can be used to remove this duplication and ensure
you get at most one result per staff entry, for example:

```sh
curl %endpoint%/staff --header 'Content-Type: application/json' --data '{
    "filters": ["and", ["ismain", "=", 1], ["id", "=", "s81"] ],
    "fields": "lang,aliases{name,latin,ismain},description,extlinks{url,label}"
}'
```

Accepted values for `"sort"`: `id`, `name`, `searchrank`.

### Filters {#staff-filters}

-----------------------------------------------------------------------------
Name                [F]   Description
------------------  ----  -------------------------------------------------------
`id`                o     vndbid

`aid`                     integer, alias identifier

`search`            m     String search.

`lang`                    Language.

`gender`                  Gender.

`role`              m     String, can either be `"seiyuu"` or one of the values
                          from `enums.staff_role` in the [schema JSON](#get-schema).
                          If this filter is used when nested inside a visual
                          novel filter, then this matches the `role` of the
                          particular visual novel.  Otherwise, this matches the
                          `role` of any linked visual novel.

`extlink`           m     Match on external links, works similar to the `extlink`
                          filter for [releases](#release-filters).

`ismain`                  Only accepts a single value, integer `1`.
-----------------------------------------------------------------------------

### Fields {#staff-fields}

id
:   vndbid.

aid
:   Integer, alias id.

ismain
:   Boolean, whether the 'name' and 'original' fields represent the main name
    for this staff entry.

name
:   String, possibly romanized name.

original
:   String, possibly null, name in original script.

lang
:   String, staff's primary language.

gender
:   String, possibly null, `"m"` or `"f"`.

description
:   String, possibly null, may contain [formatting codes](https://vndb.org/d9#4).

extlinks
:   Array, links to external websites. Works the same as the 'extlinks'
    [release field](#release-fields).

aliases
:   Array, list of names used by this person.

aliases.aid
:   Integer, alias id.

aliases.name
:   String, name in original script.

aliases.latin
:   String, possibly null, romanized version of 'name'.

aliases.ismain
:   Boolean, whether this alias is used as "main" name for the staff entry.


## POST /tag

Accepted values for `"sort"`: `id`, `name`, `vn_count`, `searchrank`.

### Filters

-----------------------------------------------------------------------------
Name                [F]   Description
------------------  ----  -------------------------------------------------------
`id`                o     vndbid

`search`            m     String search.

`category`                String, see `category` field.
-----------------------------------------------------------------------------

### Fields {#tag-fields}

id
:   vndbid.

name
:   String.

aliases
:   Array of strings.

description
:   String, may contain [formatting codes](https://vndb.org/d9#4).

category
:   String, `"cont"` for content, `"ero"` for sexual content and `"tech"` for technical tags.

searchable
:   Bool.

applicable
:   Bool.

vn\_count
:   Integer, number of VNs this tag has been applied to, including any child tags.

*Missing: some way to fetch parent/child tags. Not obvious how to do this
efficiently because tags form a DAG rather than a tree.*


## POST /trait

Accepted values for `"sort"`: `id`, `name`, `char_count`, `searchrank`.

### Filters

-----------------------------------------------------------------------------
Name                [F]   Description
------------------  ----  -------------------------------------------------------
`id`                o     vndbid

`search`            m     String search.
-----------------------------------------------------------------------------

### Fields {#trait-fields}

id
:   vndbid

name
:   String. Trait names are not necessarily self-describing, so they should
    always be displayed together with their "group" (see below), which is the
    top-level parent that the trait belongs to.

aliases
:   Array of strings.

description
:   String, may contain [formatting codes](https://vndb.org/d9#4).

searchable
:   Bool.

applicable
:   Bool.

sexual
:   Bool.

group\_id
:   vndbid

group\_name
:   String

char\_count
:   Integer, number of characters this trait has been applied to, including
    child traits.


## POST /quote

Query visual novel quotes.

Accepted values for `"sort"`: `id`, `score`.

To fetch a random quote, using the same algorithm as on the website footer:

```sh
curl %endpoint%/quote --header 'Content-Type: application/json' --data '{
    "fields": "vn{id,title},character{id,name},quote",
    "filters": [ "random", "=", 1 ]
}'
```

To fetch all quotes from a visual novel, ordered by score:

```sh
curl %endpoint%/quote --header 'Content-Type: application/json' --data '{
    "fields": "character{id,name},quote,score",
    "filters": [ "vn", "=", [ "id", "=", "v5" ] ],
    "sort": "score",
    "reverse": true
}'
```

### Filters

-----------------------------------------------------------------------------
Name                [F]   Description
------------------  ----  -------------------------------------------------------
`id`                o     vndbid

`vn`                      Match quotes from the visual novel(s) described by
                          [visual novel filters](#vn-filters).

`character`               Match quotes from the characters(s) described by
                          [character filters](#character-filters).

`random`                  Only accepts a single value, integer `1`. Matches
                          exactly one random quote from the list of *all*
                          quotes with a positive score.
-----------------------------------------------------------------------------

The `random` filter does not really combine with any other filters; adding
other filters to the query means you may randomly get zero results instead.
You *could* select more than one random quote by putting multiple `random`
filters inside an `or` clause, but then there's still the possibility that you
get fewer quotes than requested, when the algorithm happens to select the same
quote multiple times. See [random entry](#random) for alternative strategies.

### Fields {#quote-fields}

id
:   vndbid.

quote
:   String.

score
:   Integer.

vn\.*
:   Visual novel info, all [visual novel fields](#vn-fields) can be selected
    here.

character\.*
:   Character info, all [character fields](#character-fields) can be selected
    here.



# List Management

## POST /ulist

Fetch a user's list. This API is very much like `POST /vn`, except it requires
the `"user"` parameter to be set and it has a different response structure. All
[visual novel filters](#vn-filters) can be used here.

If the user has visual novel entires on their list that have been deleted from
the database, these will not be returned through the API even though they do
show up on the website.

Accepted values for `"sort"`: `id`, `title`, `released`, `rating`, `votecount`,
`voted`, `vote`, `added`, `lastmod`, `started`, `finished`, `searchrank`.

Very important example on how to fetch Yorhel's top 10 voted visual novels:

```sh
curl %endpoint%/ulist --header 'Content-Type: application/json' --data '{
    "user": "u2",
    "fields": "id, vote, vn.title",
    "filters": [ "label", "=", 7 ],
    "sort": "vote",
    "reverse": true,
    "results": 10
}'
```

### Fields {#ulist-fields}

id
:   Visual novel ID.

added
:   Integer, unix timestamp.

voted
:   Integer, can be null, unix timestamp of when the user voted on this VN.

lastmod
:   Integer, unix timestamp when the user last modified their list for this VN.

vote
:   Integer, can be null, 10 - 100.

started
:   String, start date, can be null, "YYYY-MM-DD" format.

finished
:   String, finish date, can be null.

notes
:   String, can be null.

labels
:   Array of objects, user labels assigned to this VN. Private labels are only
    listed when the user is authenticated.

labels.id
:   Integer.

labels.label
:   String.

vn\.*
:   Visual novel info, all [visual novel fields](#vn-fields) can be selected
    here.

releases
:   Array of objects, releases of this VN that the user has added to their list.

releases.list\_status
:   Integer, 0 for "Unknown", 1 for "Pending", 2 for "Obtained", 3 for "On
    loan", 4 for "Deleted".

releases.\*
:   All [release fields](#release-fields) can be selected here.


## GET /ulist\_labels

Fetch the list labels for a certain user. Accepts two query parameters:

user
:   The user ID to fetch the labels for. If the parameter is missing, the
    labels for the currently authenticated user are fetched instead.

fields
:   List of fields to select. Currently only `count` may be specified, the
    other fields are always selected.

Returns a JSON object with a single key, `"labels"`, which is an array of
objects with the following members:

id
:   Integer identifier of the label.

private
:   Boolean, whether this label is private. Private labels are only included
    when authenticated with the `listread` permission. The 'Voted' label (id=7)
    is always included even when private.

label
:   String.

count
:   Integer. The 'Voted' label may have different counts depending on whether
    the user has authenticated.

Labels with an id below 10 are the pre-defined labels and are the same for
everyone, though even pre-defined labels are excluded if they are marked
private.

Example: [Multi](https://vndb.org/u1) has only the default labels.

```sh
curl '%endpoint%/ulist_labels?user=u1'
```

## PATCH /ulist/\<id\>

Add or update a visual novel in the user's list. Requires the `listwrite`
permission. The JSON body accepts the following members:

vote
:   Integer between 10 and 100.

notes
:   String.

started
:   Date.

finished
:   Date.

labels
:   Array of integers, label ids. Setting this will overwrite any existing
    labels assigned to the VN with the given array.

labels\_set
:   Array of label ids to add to the VN, any already existing labels will
    be unaffected.

labels\_unset
:   Array of label ids to remove from the VN.

All members are be optional, missing members are not modified. A `null`
value can be used to unset a field (except for labels).

The virtual labels with id 0 ("No label") and 7 ("Voted") can not be set. The
"voted" label is automatically added/removed based on the `vote` field.

Wonky behavior alert: this API does not verify label ids and lets you add
non-existent labels. These are not displayed on the website and not returned by
[POST /ulist](#post-ulist), but they're still stored in the database and may
magically show up if a label with that id is created in the future. Don't rely
on this behavior, it's a bug.

More wonky behavior: the website automatically unsets the other
Playing/Finished/Stalled/Dropped labels when you select one of those, but this
is not enforced server-side and the API lets you set all labels at the same
time. This is totally not a bug.

Example to remove the "Playing" label, add the "Finished" label and vote a 6:

```sh
curl -XPATCH %endpoint%/ulist/v17 \
    --header 'Authorization: token hsoo-ybws4-j8yb9-qxkw-5obay-px8to-bfyk' \
    --header 'Content-Type: application/json' \
    --data '{"labels_unset":[1],"labels_set":[2],"vote":60}'
```

Or to remove an existing vote without affecting any of the other fields:

```sh
curl -XPATCH %endpoint%/ulist/v17 \
    --header 'Authorization: token hsoo-ybws4-j8yb9-qxkw-5obay-px8to-bfyk' \
    --header 'Content-Type: application/json' \
    --data '{"vote":null}'
```

Slightly unintuitive behavior alert: this API *always* adds the visual novel to
the user's list if it's not already present, and that also applies to the above
"removing a vote" example. Use [DELETE](#delete-ulistid) if you want to remove
a VN from the list.

## PATCH /rlist/\<id\>

Add or update a release in the user's list. Requires the `listwrite`
permission. All visual novels linked to the release are also added to the
user's visual novel list, if they aren't in the list yet.  The JSON body
accepts the following members:

status
:   Release status, integer. See `releases.list_status` in the [POST /ulist
    fields](#ulist-fields) for the list of possible values. Defaults to 0.

Example, to mark `r12` as obtained:

```sh
curl -XPATCH %endpoint%/rlist/r12 \
    --header 'Authorization: token hsoo-ybws4-j8yb9-qxkw-5obay-px8to-bfyk' \
    --header 'Content-Type: application/json' \
    --data '{"status":2}'
```

## DELETE /ulist/\<id\>

Remove a visual novel from the user's list. Returns success even if the VN is
not on the user's list. Removing a VN also removes any associated releases from
the user's list.

```sh
curl -XDELETE %endpoint%/ulist/v17 \
    --header 'Authorization: token hsoo-ybws4-j8yb9-qxkw-5obay-px8to-bfyk'
```

## DELETE /rlist/\<id\>

Remove a release from the user's list. Returns success even if the release is
not on the user's list. Removing a release does not remove the associated
visual novels from the user's visual novel list, that requires separate calls
to [DELETE /ulist/\<id\>](#delete-ulistid).

```sh
curl -XDELETE %endpoint%/rlist/r12 \
    --header 'Authorization: token hsoo-ybws4-j8yb9-qxkw-5obay-px8to-bfyk'
```


# HTTP Response Codes

Successful responses always return either `200 OK` with a JSON body or `204 No
Content` in the case of DELETE/PATCH requests, but errors may happen. Error
response codes are typically followed with a `text/plain` or `text/html` body.
The following is a non-exhaustive list of error codes you can expect to see:

  Code  Reason
------  -------
   400  Invalid request body or query, the included error message hopefully points at the problem.
   401  Invalid authentication token.
   404  Invalid API path or HTTP method
   429  Throttled
   500  Server error, usually points to a bug if this persists
   502  Server is down, should be temporary

# Tips & Troubleshooting

## "Too much data selected"

The server calculates a rough estimate of the number of JSON keys it would
generate in response to your query and throws an error if that estimation
exceeds a certain threshold, i.e. if the response is expected to be rather
large.  This estimation is entirely based on the `"fields"` and `"results"`
parameters, so you can work around this error by either selecting fewer fields
or fewer results.

## List of identifiers

If you have a (potentially large) list of database identifiers you'd like to
fetch, it is faster and more efficient to fetch 100 entries in a single API
call than it is to make 100 separate API calls. Simply create a filter
containing the identifiers, like in the following example:

```sh
curl %endpoint%/vn --header 'Content-Type: application/json' --data '{
  "fields": "title",
  "filters": ["or"
     , ["id","=","v1"]
     , ["id","=","v2"]
     , ["id","=","v3"]
     , ["id","=","v4"]
     , ["id","=","v5"] ],
  "results": 100
}'
```

Do not add more than 100 identifiers in a single query. You'll especially want
to avoid sending the same list of identifiers multiple times but with higher
`"page"` numbers, see also the next point.

## Pagination

While the API supports pagination through the `"page"` parameter, this is often
not the most efficient way to retrieve a large list of entries. Results are
sorted on `"id"` by default so you can also implement pagination by filtering
on this field. For example, if the last item you've received had id `"v123"`,
you can fetch the next page by filtering on `["id",">","v123"]`.

This approach tends to not work as well when sorting on other fields, so
`"page"`-based pagination is often still the better solution in those cases.

## Random entry {#random}

Fetching a random entry from a database is, in general, pretty challenging to
do in a performant way. Here's one approach that can be used with the API:
first grab the highest database identifier, then select a random number between
`1` and the highest identifier (both inclusive) and then fetch the entry with
that or the nearest increasing id, e.g.:

```sh
curl %endpoint%/vn --header 'Content-Type: application/json' --data '{
    "sort": "id",
    "reverse": true,
    "results": 1
}'
```

Then, assuming you've randomly chosen id `v4567`:

```sh
curl %endpoint%/vn --header 'Content-Type: application/json' --data '{
    "filters": [ "id", ">=", "v4567" ],
    "fields": "title",
    "results": 1
}'
```

The result of the first query can be cached. Additional filters can be added to
both queries if you want to narrow down the selection. This method has a slight
bias in its selection due to the presence of id gaps, but you most likely don't
need perfect uniform random selection anyway.

# Change Log

**2026-01-10**

- Add `image` filter to [POST /release](#post-release).

**2025-06-02**

- Add `sexual` field to [POST /trait](#post-trait).

**2025-05-02**

- Limit maximum number of filter predicates in a single request to 1000.

**2025-04-05**

- Add `gender` field to [POST /character](#post-character).

**2025-01-11**

- Add `gender` and `gender_spoil` filters to [POST /character](#post-character).

**2025-01-09**

- Add `extlink` filter and `extlinks` field to [POST /producer](#post-producer).

**2025-01-07**

- Add [POST /quote](#post-quote).

**2024-09-09**

- Add `images` field to [POST /release](#post-release).

**2024-07-06**

- Add `"n"` (sexless) as possible value for the `sex` field of [POST /character](#post-character).

**2024-06-05**

- Add `average` field to [POST /vn](#post-vn).

**2024-05-23**

- Add `extlinks` field to [POST /vn](#post-vn).

**2024-05-18**

- Add `va` field to [POST /vn](#post-vn).

**2024-05-11**

- Add `image{thumbnail,thumbnail_dims}` fields to [POST /vn](#post-vn).
  Beware: VN images can now be larger than 256x400px.

**2024-03-13**

- Add [POST /staff](#post-staff).
- Add `editions` and `staff` fields to [POST /vn](#post-vn).
- Add `enums.staff_role` and `extlinks./staff` members to [GET /schema](#get-schema).

**2023-11-20**

- Add `relations` field to [POST /vn](#post-vn).

**2023-08-02**

- Add `developers` field to [POST /vn](#post-vn).

**2023-07-11**

- Deprecated `popularity` sort options for [POST /ulist](#post-ulist) and [POST
  /vn](#post-vn), it's now equivalent to sorting on the reverse of `votecount`.
- Deprecated `popularity` filter and field for [POST /vn](#post-vn).

**2023-04-05**

- Add `searchrank` sort option to all endpoints that have a `search` filter.

**2023-03-19**

- Add `voiced`, `gtin` and `catalog` fields to [POST /release](#post-release).

**2023-01-17**

- Add `listwrite` permission to API tokens.
- Add [PATCH /ulist/\<id>](#patch-ulistid).
- Add [PATCH /rlist/\<id>](#patch-rlistid).
- Add [DELETE /ulist/\<id>](#delete-ulistid).
- Add [DELETE /rlist/\<id>](#delete-rlistid).

[F]: #filter-flags
