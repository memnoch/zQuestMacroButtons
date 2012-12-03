--
--
--	UTF-8 file
--

if GetLocale() ~= "deDE" then return end

Grail.holidayMapping = { ['A'] = 'Liebe liegt in der Luft', ['B'] = 'Braufest', ['C'] = "Kinderwoche", ['D'] = 'Tag der Toten', ['F'] = 'Dunkelmond-Jahrmarkt', ['H'] = 'Erntedankfest', ['L'] = 'Mondfest', ['M'] = 'Midsummer Fire Festival', ['N'] = 'Nobelgarten', ['P'] = "Pirates' Day", ['U'] = 'Neujahr', ['V'] = 'Winterhauch', ['W'] = "Schlotternächte", ['Y'] = "Die Pilgerfreuden", }

Grail.professionMapping = { ['A'] = 'Alchemie', ['B'] = 'Schmiedekunst', ['C'] = 'Kochkunst', ['E'] = 'Verzauberkunst', ['F'] = 'Angeln', ['H'] = 'Kräuterkunde', ['I'] = 'Inschriftenkunde', ['J'] = 'Juwelenschleifen', ['L'] = 'Lederverarbeitung', ['M'] = 'Bergbau', ['N'] = 'Ingenieurskunst', ['P'] = 'Lockpicking', ['R'] = 'Reiten', ['S'] = 'Kürschnerei', ['T'] = 'Schneiderei', ['U'] = 'Runeforging', ['X'] = 'Archäologie', ['+'] = 'Erste Hilfe', }

Grail.reputationMapping = {
	[01] = 'Darnassus', [02] = 'Gnomeregangnome', [03] = 'Eisenschmiede', [04] = 'Sturmwind', [05] = 'Die Exodar', [06] = 'Gilneas', [07] = 'Dunkelspeertrolle', [08] = 'Orgrimmar',
	[09] = 'Donnerfels', [10] = 'Unterstadt', [11] = 'Silbermond', [12] = 'Bilgewasserkartell', [13] = 'Der Bund von Arathor', [14] = 'Silberschwingen', [15] = 'Sturmlanzengarde', [16] = 'Die Entweihten',
	[17] = 'Frostwolfklan', [18] = 'Vorhut des Kriegshymnenklan', [19] = 'Beutebucht', [20] = 'Ewige Warte', [21] = 'Gadgetzan', [22] = 'Ratschet', [23] = 'Expedition des Cenarius', [24] = 'Ehrenfeste',
	[25] = 'Kurenai', [26] = "Die Mag'har", [27] = "Ogri'la", [28] = 'Netherschwingen', [29] = 'Sporeggar', [30] = 'Das Konsortium', [31] = 'Thrallmar', [32] = 'Unteres Viertel',
	[33] = "Himmelswache der Sha'tari", [34] = 'Offensive der Zerschmetterten Sonne', [35] = 'Die Aldor', [36] = 'Die Seher', [37] = "Die Sha'tar", [38] = 'Vorposten der Allianz', [39] = 'Argentumkreuzzug', [40] = "Forscherliga",
	[41] = 'Stamm der Wildherzen', [42] = 'Die Frosterben', [43] = 'Die Hand der Rache', [44] = 'Expedition der Horde', [45] = "Die Kalu'ak", [46] = 'Ritter der Schwarzen Klinge', [47] = 'Die Orakel', [48] = 'Die Söhne Hodirs',
	[49] = 'Die Taunka', [50] = 'Expedition Valianz', [51] = 'Kriegshymnenoffensive', [52] = 'Der Wyrmruhpakt', [53] = 'Kirin Tor', [54] = 'Der Silberbund', [55] = 'Die Sonnenhäscher', [56] = 'Wächter des Hyjal',
	[57] = 'Der Irdene Ring', [58] = 'Therazane', [59] = 'Das Äscherne Verdikt', [60] = 'Die Todeshörigen', [61] = 'Brut Nozdormus', [62] = 'Zirkel des Cenarius', [63] = 'Hydraxianer', [64] = 'Die Wächter der Sande',
	[65] = 'Stamm der Zandalari', [66] = 'Argentumdämmerung', [67] = 'Blutsegelbukaniere', [68] = 'Dunkelmond-Jahrmarkt', [69] = 'Gelkisklan', [70] = 'Hüter der Zeit', [71] = 'Magramklan', [72] = 'Rabenholdt',
	[73] = "Shen'dralar", [74] = 'Syndikat', [75] = 'Thoriumbruderschaft', [76] = 'Holzschlundfeste', [77] = 'Tristessa', [78] = 'Das Violette Auge', [79] = 'Wintersäblerausbilder', [80] = 'Wildhammerklan',
	[81] = 'Ramkahen',
	}
