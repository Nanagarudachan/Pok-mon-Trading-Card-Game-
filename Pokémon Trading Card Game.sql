
--------------------------------------------------------------------
-- Schritt 1: Neue Datenbank erstellen -> Pokémon Trading Card Games
--------------------------------------------------------------------

--------------------------------------------------
-- Schritt 2: Tabellenstruktur (normalisiert):
--------------------------------------------------

--------------------------------------------------
-- Sets
--------------------------------------------------
CREATE TABLE sets (
    set_id TEXT PRIMARY KEY,
    set_name TEXT,
    series TEXT,
    publisher TEXT,
    release_date DATE
);

--------------------------------------------------
-- Artists
--------------------------------------------------
CREATE TABLE artists (
    artist_id SERIAL PRIMARY KEY,
    artist_name TEXT UNIQUE
);

--------------------------------------------------
-- Cards
--------------------------------------------------
CREATE TABLE cards (
    id TEXT PRIMARY KEY,
    name TEXT,
    hp FLOAT,
    level TEXT,
    evolves_from TEXT,
    rarity TEXT,
    flavor_text TEXT,
    converted_retreat_cost FLOAT,
    regulation_mark TEXT,
    set_id TEXT REFERENCES sets(set_id),
    artist_id INT REFERENCES artists(artist_id)
);

--------------------------------------------------
-- Types
--------------------------------------------------
CREATE TABLE types (
    type_id SERIAL PRIMARY KEY,
    type_name TEXT UNIQUE
);

--------------------------------------------------
-- Verbindung Cards ↔ Types (M:N)
--------------------------------------------------
CREATE TABLE card_types (
    card_id TEXT REFERENCES cards(id),
    type_id INT REFERENCES types(type_id),
    PRIMARY KEY (card_id, type_id)
);

--------------------------------------------------
-- Attacks
--------------------------------------------------
CREATE TABLE attacks (
    attack_id SERIAL PRIMARY KEY,
    card_id TEXT REFERENCES cards(id),
    name TEXT,
    damage TEXT,
    text TEXT
);

--------------------------------------------------
-- Abilities
--------------------------------------------------
CREATE TABLE abilities (
    ability_id SERIAL PRIMARY KEY,
    card_id TEXT REFERENCES cards(id),
    name TEXT,
    text TEXT
);

--------------------------------------------------
-- Weaknesses
--------------------------------------------------
CREATE TABLE weaknesses (
    weakness_id SERIAL PRIMARY KEY,
    card_id TEXT REFERENCES cards(id),
    type TEXT,
    value TEXT
);

--------------------------------------------------
-- Legalities
--------------------------------------------------
CREATE TABLE legalities (
    card_id TEXT REFERENCES cards(id),
    format TEXT,
    status TEXT,
    PRIMARY KEY (card_id, format)
);

-----------------------------------------------------------
-- Schritt 3: CSV erstmal roh importieren (Zwischentabelle)
-----------------------------------------------------------

CREATE TABLE raw_cards (
    id TEXT,
    set TEXT,
    series TEXT,
    publisher TEXT,
    generation TEXT,
    release_date TEXT,
    artist TEXT,
    name TEXT,
    set_num TEXT,
    types TEXT,
    supertype TEXT,
    subtypes TEXT,
    level TEXT,
    hp TEXT,
    evolvesFrom TEXT,
    evolvesTo TEXT,
    abilities TEXT,
    attacks TEXT,
    weaknesses TEXT,
    retreatCost TEXT,
    convertedRetreatCost TEXT,
    rarity TEXT,
    flavorText TEXT,
    nationalPokedexNumbers TEXT,
    legalities TEXT,
    resistances TEXT,
    rules TEXT,
    regulationMark TEXT,
    ancientTrait TEXT
);

--------------------------------------------------
-- CSV importieren
--------------------------------------------------

COPY raw_cards
FROM 'C:\Users\User\Desktop\Smart Future Campus\31_03_2026\ZIP\pokemon-tcg-data-master 1999-2023.csv'
DELIMITER ','
CSV HEADER;

--------------------------------------------------
-- Schritt 4: Normalisierung / Daten einfügen
--------------------------------------------------

--------------------------------------------------
-- Sets
--------------------------------------------------

INSERT INTO sets (set_id, set_name, series, publisher, release_date)
SELECT DISTINCT
    set,
    set,
    series,
    publisher,
    CASE 
        WHEN release_date ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
        THEN TO_DATE(release_date, 'MM/DD/YYYY')
        ELSE NULL
    END
FROM raw_cards
WHERE set IS NOT NULL
ON CONFLICT (set_id) DO NOTHING;

--------------------------------------------------
-- Artists
--------------------------------------------------

INSERT INTO artists (artist_name)
SELECT DISTINCT artist
FROM raw_cards
WHERE artist IS NOT NULL
ON CONFLICT (artist_name) DO NOTHING;

--------------------------------------------------
-- Types (aus CSV extrahieren)
--------------------------------------------------

INSERT INTO types (type_name)
SELECT DISTINCT TRIM(REPLACE(REPLACE(value, '''', ''), '"', ''))
FROM raw_cards,
LATERAL UNNEST(
    STRING_TO_ARRAY(
        REPLACE(REPLACE(types, '[', ''), ']', ''),
        ','
    )
) AS value
WHERE types IS NOT NULL
ON CONFLICT (type_name) DO NOTHING;

--------------------------------------------------
-- Cards
--------------------------------------------------

INSERT INTO cards (
    id, name, hp, level, evolves_from,
    rarity, flavor_text, converted_retreat_cost,
    regulation_mark, set_id, artist_id
)
SELECT
    r.id,
    r.name,
    NULLIF(r.hp, '')::FLOAT,
    r.level,
    r.evolvesFrom,
    r.rarity,
    r.flavorText,
    NULLIF(r.convertedRetreatCost, '')::FLOAT,
    r.regulationMark,
    r.set,
    a.artist_id
FROM raw_cards r
LEFT JOIN artists a ON r.artist = a.artist_name
ON CONFLICT (id) DO NOTHING;

--------------------------------------------------
-- Card <-> Types (M:N)
--------------------------------------------------

INSERT INTO card_types (card_id, type_id)
SELECT
    r.id,
    t.type_id
FROM raw_cards r,
LATERAL UNNEST(
    STRING_TO_ARRAY(
        REPLACE(REPLACE(r.types, '[', ''), ']', ''),
        ','
    )
) AS value
JOIN types t 
ON t.type_name = TRIM(REPLACE(REPLACE(value, '''', ''), '"', ''))
ON CONFLICT (card_id, type_id) DO NOTHING;

--------------------------------------------------
-- Abilities
--------------------------------------------------

CREATE TABLE abilities_raw (
    card_id TEXT,
    ability_text TEXT
);

INSERT INTO abilities_raw (card_id, ability_text)
SELECT id, abilities
FROM raw_cards
WHERE abilities IS NOT NULL AND abilities <> '[]';

--------------------------------------------------
-- Attacks
--------------------------------------------------

CREATE TABLE attacks_raw (
    card_id TEXT,
    attack_text TEXT
);

INSERT INTO attacks_raw (card_id, attack_text)
SELECT id, attacks
FROM raw_cards
WHERE attacks IS NOT NULL AND attacks <> '[]';

--------------------------------------------------
-- Weaknesses
--------------------------------------------------

CREATE TABLE weaknesses_raw (
    card_id TEXT,
    weakness_text TEXT
);

INSERT INTO weaknesses_raw (card_id, weakness_text)
SELECT id, weaknesses
FROM raw_cards
WHERE weaknesses IS NOT NULL AND weaknesses <> '[]';

--------------------------------------------------
-- Legalities
--------------------------------------------------

CREATE TABLE legalities_raw (
    card_id TEXT,
    legalities_text TEXT
);

INSERT INTO legalities_raw (card_id, legalities_text)
SELECT id, legalities
FROM raw_cards
WHERE legalities IS NOT NULL AND legalities <> '{}';

-------------------------------------------------------------------------------------------------------------------

--------------------------------------------------
-- Schritt 5: Fragenstellungen
--------------------------------------------------

/* 
1.	Welche Tabellen bzw. Datentabellen enthält der Datensatz?
	Liste für jede Tabelle die Spaltennamen, Datentypen und kurz, welche 
	Informationen sie enthält.

	Antwort:
	
	Tabelle: Cards
	| Spalte                 | Datentyp  | Beschreibung         |
	| ---------------------- | --------- | -------------------- |
	| id                     | TEXT (PK) | Eindeutige Karten-ID |
	| name                   | TEXT      | Kartenname           |
	| hp                     | FLOAT     | Trefferpunkte        |
	| level                  | TEXT      | Level                |
	| evolves_from           | TEXT      | Vorentwicklung       |
	| rarity                 | TEXT      | Seltenheit           |
	| flavor_text            | TEXT      | Beschreibung         |
	| converted_retreat_cost | FLOAT     | Rückzugskosten       |
	| regulation_mark        | TEXT      | Turnierkennzeichnung |
	| set_id                 | TEXT (FK) | Referenz auf sets    |
	| artist_id              | INT (FK)  | Referenz auf artists |

	Zweck: Haupttabelle mit allen Pokémon-Karten
	
	Tabelle: sets
	| Spalte       | Datentyp  | Beschreibung           |
	| ------------ | --------- | ---------------------- |
	| set_id       | TEXT (PK) | Set-ID                 |
	| set_name     | TEXT      | Name des Sets          |
	| series       | TEXT      | Serie                  |
	| publisher    | TEXT      | Herausgeber            |
	| release_date | DATE      | Veröffentlichungsdatum |
	
	Zweck: Informationen zu Karten-Erweiterungen
	
	Tabelle: artists
	| Spalte      | Datentyp    | Beschreibung |
	| ----------- | ----------- | ------------ |
	| artist_id   | SERIAL (PK) | ID           |
	| artist_name | TEXT        | Künstler     |

	Zweck: Künstler der Karten

	Tabelle: types
	| Spalte    | Datentyp    | Beschreibung       |
	| --------- | ----------- | ------------------ |
	| type_id   | SERIAL (PK) | ID                 |
	| type_name | TEXT        | Typ (Fire, Water…) |

	Zweck: Pokémon-Typen

	Tabelle: card_types (M:N)
	| Spalte  | Datentyp  | Beschreibung |
	| ------- | --------- | ------------ |
	| card_id | TEXT (FK) | Karte        |
	| type_id | INT (FK)  | Typ          |

	Zweck: Verbindung Karten <-> Typen

	Tabelle: attacks
	| Spalte    | Datentyp    | Beschreibung |
	| --------- | ----------- | ------------ |
	| attack_id | SERIAL (PK) | ID           |
	| card_id   | TEXT (FK)   | Karte        |
	| name      | TEXT        | Attacke      |
	| damage    | TEXT        | Schaden      |
	| text      | TEXT        | Beschreibung |


	Tabelle: Abilities
	| Spalte     | Datentyp    | Beschreibung |
	| ---------- | ----------- | ------------ |
	| ability_id | SERIAL (PK) | ID           |
	| card_id    | TEXT (FK)   | Karte        |
	| name       | TEXT        | Fähigkeit    |
	| text       | TEXT        | Beschreibung |

	Tabelle: Weaknesses
	| Spalte      | Datentyp    | Beschreibung |
	| ----------- | ----------- | ------------ |
	| weakness_id | SERIAL (PK) | ID           |
	| card_id     | TEXT (FK)   | Karte        |
	| type        | TEXT        | Schwäche     |
	| value       | TEXT        | Wert         |

	Tabelle: legalities
	| Spalte  | Datentyp  | Beschreibung     |
	| ------- | --------- | ---------------- |
	| card_id | TEXT (FK) | Karte            |
	| format  | TEXT      | Spielmodus       |
	| status  | TEXT      | erlaubt/verboten |

	Tabelle: Raw_Cards --> Komplette CSV
	abilities_raw
	attacks_raw
	weaknesses_raw
	legalities_raw
	
	Zweck:
	Zwischenspeicherung
	Vorbereitung für Parsing

*/


/* 
2.	Identifiziere einen geeigneten Primärschlüssel für die(n) Tabelle(n).
	Falls kein expliziter Primärschlüssel vorhanden ist, definiere einen geeigneten 
	eindeutigen Schlüssel:

	Antwort: 

	| Tabelle        | Primärschlüssel    | Begründung                   |
	| -------------- | ------------------ | ---------------------------- |
	| cards          | id                 | eindeutig pro Karte          |
	| sets           | set_id             | eindeutige Set-ID            |
	| artists        | artist_id          | künstlicher Schlüssel        |
	| types          | type_id            | künstlicher Schlüssel        |
	| card_types     | (card_id, type_id) | Kombination eindeutig        |
	| attacks        | attack_id          | mehrere Attacken pro Karte   |
	| abilities      | ability_id         | mehrere Fähigkeiten möglich  |
	| weaknesses     | weakness_id        | mehrere Schwächen möglich    |
	| legalities     | (card_id, format)  | pro Format eindeutig         |
	| raw_cards      | X keiner           | Rohdaten, nicht normalisiert |
	| abilities_raw  | X keiner           | Zwischentabelle              |
	| attacks_raw    | X keiner           | Zwischentabelle              |
	| weaknesses_raw | X keiner           | Zwischentabelle              |
	| legalities_raw | X keiner           | Zwischentabelle              |

*/


/* 
3.	Wie viele Pokémon-TCG-Karten sind insgesamt im Datensatz enthalten?
*/

SELECT COUNT(*) AS "Anzahl der Karten"
FROM cards;

/*
Lösung:
Anzahk der Karten: 17172
*/


/* 
4.	Welche Pokémon-Kartentypen (z. B. Feuer, Wasser, Pflanze etc.) kommen wie 
	häufig vor?
*/

SELECT t.type_name, COUNT(*) AS anzahl
FROM card_types ct
JOIN types t ON ct.type_id = t.type_id
GROUP BY t.type_name
ORDER BY anzahl DESC;

/*
Lösung:
"type_name"		"anzahl"
"Water"			2113
"Grass"			2025
"Psychic"		1955
"Colorless"		1870
"Fighting"		1583
"Fire"			1304
"Lightning"		1290
"Darkness"		993
"Metal"			800
"Dragon"		433
"Fairy"			237
*/


/* 
5.	Analysiere die Seltenheiten:
	- Welche Seltenheitsstufen existieren?
	- Wie viele Karten gehören zu jeder Seltenheitsstufe?
*/

SELECT rarity, COUNT(*) AS anzahl
FROM cards
GROUP BY rarity
ORDER BY anzahl DESC;

/*
Lösung:
"rarity"						"anzahl"
"Common"						4346
"Uncommon"						4213
"Rare"							2320
"Rare Holo"						1617
"Promo"							1107
"Rare Ultra"					798
"Rare Secret"					325
"Rare Rainbow"					324
"Rare Holo EX"					318
"null"							295
"Rare Holo V"					282
"Rare Holo GX"					165
"Rare Shiny"					149
"Illustration Rare"				122
"Rare Holo VMAX"				110
"Ultra Rare"					102
"Double Rare"					82
"Trainer Gallery Rare Holo"		80
"Rare Holo LV.X"				56
"Special Illustration Rare"		53
"Rare Holo VSTAR"				44
"Rare Shiny GX"					35
"Hyper Rare"					28
"Rare Prism Star"				27
"Rare BREAK"					27
"Rare Prime"					26
"Rare Holo Star"				25
"Classic Collection"			25
"LEGEND"						18
"Rare Shining"					16
"Radiant Rare"					15
"Rare ACE"						13
"Amazing Rare"					9
*/


/* 
6.	Wie verteilen sich die Karten über die verschiedenen Jahre oder Sets?
*/

SELECT EXTRACT(YEAR FROM s.release_date) AS jahr, COUNT(*) AS anzahl
FROM cards c
JOIN sets s ON c.set_id = s.set_id
GROUP BY jahr
ORDER BY jahr;

/*
Lösung:
"jahr"	"anzahl"
1999	281
2000	588
2001	159
2002	397
2003	713
2004	463
2005	491
2006	463
2007	584
2008	492
2009	550
2010	439
2011	534
2012	528
2013	760
2014	506
2015	588
2016	613
2017	1000
2018	847
2019	1586
2020	914
2021	1085
2022	1057
2023	1534
*/


/* 
7.	Gibt es bestimmte Kartentypen, die im Durchschnitt höhere HP-Werte haben?
	Führe mindestens eine vergleichende Analyse zwischen Typen durch.
*/

SELECT t.type_name, AVG(c.hp) AS avg_hp
FROM cards c
JOIN card_types ct ON c.id = ct.card_id
JOIN types t ON ct.type_id = t.type_id
WHERE c.hp IS NOT NULL
GROUP BY t.type_name
ORDER BY avg_hp DESC;

/*
Lösung:
"type_name"		"avg_hp"
"Dragon"		152.84064665127022
"Metal"			124.175
"Darkness"		116.2134944612286
"Fire"			110.03834355828221
"Fighting"		107.11939355653821
"Fairy"			106.16033755274262
"Lightning"		103.32558139534883
"Water"			102.94368196876479
"Psychic"		100.80348004094166
"Colorless"		94.81263383297645
"Grass"			93.22962962962963
*/


/* 
8.	Welche Pokémon-Karten haben den höchsten Schaden (Attack Power) und 
	welche den niedrigsten?
*/

-- Höchster Schaden (erste Zahl aus attack_text extrahieren)

SELECT c.name, 
       (REGEXP_MATCHES(a.attack_text, '\d+'))[1]::INT AS damage
FROM cards c
JOIN attacks_raw a ON c.id = a.card_id
WHERE a.attack_text ~ '\d+'
ORDER BY damage DESC
LIMIT 10;

/*
Lösung:
"name"				"damage"
"Copperajah ex"		260
"Copperajah ex"		260
"Slaking"			240
"Pawmot"			230
"Pawmot"			230
"Koraidon ex"		220
"Miraidon ex"		220
"Miraidon ex"		220
"Koraidon ex"		220
"Miraidon ex"		220
*/

-- Niedrigster Schaden
SELECT 
    c.name,
    MIN((match)[1]::INT) AS damage
FROM cards c
JOIN attacks_raw a ON c.id = a.card_id
JOIN LATERAL regexp_matches(a.attack_text, '\d+', 'g') AS match ON TRUE		-- extrahiert jede einzelne Zahl separat
GROUP BY c.name
ORDER BY damage ASC
LIMIT 10;

/*
Lösung:
"name"					"damage"
"Weedle"				0
"Totodile"				0
"Hisuian Electrode"		0
"Hisuian Zoroark V"		0
"Golduck"				0
"Celebi"				0
"Sableye G"				0
"Alolan Sandslash"		0
"Chimchar"				0
"Murkrow"				0
*/


/* 
9.	Untersuche Kosten-Effizienz:
	- Gibt es Zusammenhänge zwischen Kartenkosten und Schaden?
	- Welche Kartentypen erzeugen relativ hohen Schaden bei niedrigen Kosten?
*/

-- Durchschnittlicher Schaden pro Retreat Cost
SELECT 
    c.converted_retreat_cost,
    AVG(match.damage::INT) AS avg_damage
FROM cards c
JOIN attacks_raw a ON c.id = a.card_id
-- LATERAL zum Extrahieren der ersten Zahl aus attack_text
JOIN LATERAL (
    SELECT (REGEXP_MATCHES(a.attack_text, '\d+'))[1] AS damage
) AS match ON TRUE
GROUP BY c.converted_retreat_cost
ORDER BY c.converted_retreat_cost;

/*
Lösung:
"converted_retreat_cost"	"avg_damage"
1							2.1077718758736371
2							3.5312958435207824
3							4.4899216125419933
4							6.1642743221690590
5							2.5000000000000000
0							2.6214622641509434
*/


-- Typen nach Schaden / Kosten Ratio
SELECT 
    t.type_name,
    AVG(match.damage::INT) AS avg_damage,
    AVG(c.converted_retreat_cost) AS avg_cost,
    AVG(match.damage::INT) / NULLIF(AVG(c.converted_retreat_cost),0) AS damage_per_cost
FROM cards c
JOIN attacks_raw a ON c.id = a.card_id
JOIN card_types ct ON c.id = ct.card_id
JOIN types t ON ct.type_id = t.type_id
JOIN LATERAL (
    SELECT (REGEXP_MATCHES(a.attack_text, '\d+'))[1] AS damage
) AS match ON TRUE
GROUP BY t.type_name
ORDER BY damage_per_cost DESC;

/*
Lösung:
"type_name"		"avg_damage"		"avg_cost"			"damage_per_cost"
"Lightning"		3.7121799844840962	1.4262435677530017	2.602767204996065
"Darkness"		3.4521651560926485	1.694327731092437	2.037483712709362
"Fighting"		3.8034134007585335	1.9960988296488946	1.9054233909989005
"Grass"			2.8582015810276680	1.5508565310492506	1.8429825865929181
"Psychic"		2.7751024590163934	1.5267467248908297	1.817657384668585
"Water"			2.8203791469194313	1.7400686611083864	1.6208435965526269
"Colorless"		2.5051323608860076	1.5823981098641464	1.5831239593057151
"Fire"			2.7632590315142198	1.7696629213483146	1.5614606590778766
"Metal"			3.4212500000000000	2.217005076142132	1.5431854607899256
"Fairy"			1.6965811965811966	1.4646017699115044	1.1583907867895784
"Dragon"		2.3903002309468822	2.0663390663390664	1.1567802544534853
*/


/* 
10.	Welche Sets oder Zeitperioden brachten die meisten Karten hervor?
*/

SELECT s.set_name, COUNT(*) AS anzahl
FROM cards c
JOIN sets s ON c.set_id = s.set_id
GROUP BY s.set_name
ORDER BY anzahl DESC
LIMIT 10;

/*
Lösung:
"set_name"					"anzahl"
"SWSH Black Star Promos"	302
"Fusion Strike"				284
"Paldea Evolved"			279
"Cosmic Eclipse"			272
"Paradox Rift"				266
"Unified Minds"				261
"Scarlet & Violet"			258
"SM Black Star Promos"		251
"Lost Thunder"				240
"Unbroken Bonds"			238
*/


/* 
11.	. Identifiziere mindestens 3 weitere selbst gewählte interessante 
	Fragestellungen und beantworte sie – z. B. Kombinationen von Typen, 
	Entwicklungen, Fähigkeiten, HP-Verteilungen, seltene Muster etc.
	
	(Optional: Erstelle Views, die für typische Auswertungen nützlich sind, z. B. 
	„Top-10 Karten nach Schaden“, „Kartentypen nach HP-Durchschnitt“, 
	„Set-Statistiken“.)
*/

-- Top 10 Karten mit HP 120

SELECT name, hp
FROM cards
WHERE hp = 120
ORDER BY hp DESC;


SELECT name, hp
FROM cards
WHERE hp = 120
ORDER BY hp DESC
LIMIT 10;


/*
Lösung:

Insgesamt sind es 743 Karten mit 120 HP

Und die Top 10:
"name"						"hp"
"Chansey"					120
"Charizard"					120
"Chansey"					120
"Charizard"					120
"Giovanni's Nidoking"		120
"Feraligatr"				120
"Charizard"					120
"Blissey"					120
"Charizard"					120
"Feraligatr"				120
*/


-- Karten mit den meisten Attacken

SELECT c.name, COUNT(*) AS anzahl_attacks
FROM cards c
JOIN attacks_raw a ON c.id = a.card_id
GROUP BY c.name
ORDER BY anzahl_attacks DESC
LIMIT 10;

/*
Lösung:
"name"			"anzahl_attacks"
"Pikachu"		98
"Eevee"			58
"Magnemite"		41
"Raichu"		41
"Charmander"	38
"Unown"			36
"Magneton"		36
"Snorlax"		35
"Magikarp"		34
"Voltorb"		32
*/

-- Entwicklung über Zeit

SELECT EXTRACT(YEAR FROM s.release_date) AS jahr, 
AVG(c.hp) AS avg_hp FROM cards c 
JOIN sets s ON c.set_id = s.set_id 
GROUP BY jahr 
ORDER BY jahr;

/*
Lösung:
"jahr"	"avg_hp"
1999	62.333333333333336
2000	59.60919540229885
2001	61.266666666666666
2002	65.46783625730994
2003	68.75605815831987
2004	70.75566750629723
2005	69.92753623188406
2006	70.80103359173127
2007	77.10317460317461
2008	78.2247191011236
2009	81.01593625498008
2010	81.81102362204724
2011	87.14893617021276
2012	93.47916666666667
2013	104.49704142011835
2014	98.78281622911695
2015	106.16977225672878
2016	106.32860040567951
2017	125.7327080890973
2018	112.94642857142857
2019	133.72733865119653
2020	130.96
2021	139.79545454545453
2022	143.0500582072177
2023	126.8989280245023
*/