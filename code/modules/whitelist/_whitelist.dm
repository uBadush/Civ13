/* A new whitelist system that uses SQLite. How this works:
  0. there are two built in whitelists with special behavior, jobs & server
  I. make a whitelist type for what you want to whitelist
  II. make sure the new type has a unique 'name' variable
  III. make a global variable for that whitelist
*/

var/list/global_whitelists[50]

/client/proc/validate_whitelist(name, return_real_val_even_if_whitelist_disabled = FALSE)
	for (var/_name in global_whitelists)
		if (_name == name)
			var/datum/whitelist/W = global_whitelists[_name]
			if (W.validate(src, return_real_val_even_if_whitelist_disabled))
				return TRUE
			else
				return FALSE

	return TRUE // didn't find the whitelist? validate them anyway

/proc/save_all_whitelists()
	for (var/key in global_whitelists)
		var/datum/whitelist/W = global_whitelists[key]
		if (W)
			W.save()

/proc/save_whitelist(whatkey)
	for (var/key in global_whitelists)
		if (key == whatkey)
			var/datum/whitelist/W = global_whitelists[key]
			W.save()
			return TRUE
	return FALSE

/datum/whitelist
	var/name = "generic whitelist"
	var/data = ""
	var/enabled = FALSE
	var/file = ""

// when we're created
/datum/whitelist/New()
	..()
	load()

// load the whitelist from the database
/datum/whitelist/proc/load()
	var/F = file("SQL/whitelist.txt")
	if (!F)
		return
	var/list/_data = list()
	var/list/WWcheck = splittext(file2text(F),"|")
	if (islist(WWcheck) && !isemptylist(WWcheck))
		for(var/i=1;i<WWcheck.len;i++)
			var/list/WWcheck_two = list(splittext(WWcheck[i], "="))
			_data += WWcheck_two[1]


// save the whitelist to the database
/datum/whitelist/proc/save()
	var/F = file("SQL/whitelist.txt")
	if (!F)
		return
/*
	var/list/rowdata = database.execute("SELECT * FROM whitelists WHERE key = '[name]';")
	sleep(10)
	if (islist(rowdata) && !isemptylist(rowdata))
		database.execute("UPDATE whitelists SET val = '[data]' WHERE key = '[name]'", FALSE)
	else
		database.execute("INSERT INTO whitelists (key, val) VALUES ('[name]', '[data]');", FALSE)
*/
// add a client or ckey to the whitelist
/datum/whitelist/proc/add(_arg, var/list/extras = list())

	if (!extras.len)
		remove(_arg) // no duplicates

	if (data)
		data += "&"
	if (isclient(_arg))
		data += _arg:ckey
	else
		data += ckey(_arg) // todo: probably shouldn't do this for other WLs

	for (var/extrafield in extras)
		data += "=[extrafield]"

	cleanup()

// remove a client or ckey from the whitelist
// if the client was in the whitelist, and was removed: return TRUE
// otherwise: return FALSE
/datum/whitelist/proc/remove(_arg)
	. = FALSE
	var/list/datalist = splittext(data, "&")
	if (isclient(_arg))
		var/client/C = _arg
		for (var/ckey in datalist)
			if (ckey == C.ckey)
				datalist -= ckey
				. = TRUE
				break
	else if (istext(_arg))
		_arg = ckey(_arg)
		for (var/ckey in datalist)
			if (ckey == _arg)
				datalist -= _arg
				. = TRUE
				break
	data = list2params(datalist)
	cleanup()

// check if a client or ckey is in the whitelist
/datum/whitelist/proc/validate(_arg, return_real_val_even_if_whitelist_disabled = FALSE)
	if (!enabled && !return_real_val_even_if_whitelist_disabled)
		return TRUE
	if (isclient(_arg))
		var/client/C = _arg
		var/path = "SQL/whitelist.txt"
		var/full_list = file2text(path)
		var/list/full_list_split = splittext(full_list, "\n")
		for (var/v = TRUE, v < full_list_split.len, v++)
			var/list/linesplit = splittext(full_list_split[v], "=")
			if (linesplit[1] == C.ckey)
				return TRUE
			if (ckey(linesplit[1]) == C.ckey)
				return TRUE
			if (lowertext(linesplit[1]) == C.ckey)
				return TRUE
	return FALSE

/datum/whitelist/proc/cleanup()
	// clean up our data. Sometimes we get stuff like multiple '&&'
	// since ckeys can't contain '&', there's no harm in deleting those
	data = replacetext(data, "&&&&", "&")
	data = replacetext(data, "&&&", "&")
	data = replacetext(data, "&&", "&")

// subtypes

/datum/whitelist/server
	name = "server"

/datum/whitelist/server/validate(client_or_ckey, return_real_val_even_if_whitelist_disabled)
	if (!enabled && !return_real_val_even_if_whitelist_disabled)
		return TRUE
	if (isclient(client_or_ckey))
		client_or_ckey = client_or_ckey:ckey
	var/path = "SQL/whitelist.txt"
	var/full_list = file2text(path)
	var/list/full_list_split = splittext(full_list, "\n")
	for (var/v = TRUE, v < full_list_split.len, v++)
		var/list/linesplit = splittext(full_list_split[v], "=")
		if (linesplit[1] == client_or_ckey)
			return TRUE
		if (ckey(linesplit[1]) == client_or_ckey)
			return TRUE
		if (lowertext(linesplit[1]) == client_or_ckey)
			return TRUE
	return FALSE

/datum/whitelist/server/New()
	..()
	if (config.usewhitelist)
		enabled = TRUE