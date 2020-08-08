;***************************************************************************************
;*BZT-CNC.de
;*Westring 18
;*33818 Leopoldshoehe
;*Germany
;***************************************************************************************
;*MACRO CNC V2.0
;*PFX 500-H
;***************************************************************************************
;DOKU
;***************************************************************************************
;Verwendete Variablen
;   #30N0...30N9 reserviert  fuer userSubN
;   #3500 INIT
;   #4503 Maximale Werkzeuglaenge                                (WZL-Vermessung)
;   #4506 Sicherheitshoehe als Maschinenkoordinate        (WZL-Vermessung)
;   #4507 Positionsangabe der X Achse                 (WZL-Vermessung)
;   #4508 Positionsangabe der Y Achse                (WZL-Vermessung)
;   #4509 Abstand Spindelnase zu Laengensensor von Z0 aus, positiver Wert         (WZL-Vermessung)
;   #4510 Werkzeuglaengentasterhoehe                        (WZL-Vermessung)
;   #4511 Freifahrhoehe                        (ZNP-Vermessung)
;   #4512 Antastgeschwindigkeit zum Taster "suchen"        (ZNP-Vermessung)
;   #4513 Tastgeschwindigkeit zum Messen            (ZNP-Vermessung)
;   #4518 Merker (Achse zurueckfahren auf Z Vermessungspunkt)
;   #4520 Werkzeugwechseltyp 0= WPos Anfahren + Vermessen 1= WPos anfahren
;   #4521 (TYP 0) Werkzeugwechselpos  X 
;   #4523 (TYP 0) Werkzeugwechselpos  Z
;   #4527 Abstand Taster zum Spindelkopf bei Z0
;   #4529 3D Taster Laenge gemessen ab Spindelende
;   #4530 Abstand z0 Maschine zu Tisch (positiv, Abstand in mm)
;   #4531 Config wurde erfolgreich durchlaufen
;   #4540 Speicherplatz fuer Punkte zur Werkstueckerfassung
;   #4556 Ende des Speicherplatzes zu obiger Zeile
;   #5000 und hoeher: Sonderbedeutung siehe Handbuch der Steuersoftware
; 
;Eingaenge auf USBCNC:
;
;Eingang 1 - AUX IN: E01 WZM-Klappe Offen        1 = offen        (oeFFNER)
;Eingang 2 - AUX IN: E02 WZM-Ausgefahren        1 = ausgefahren        (oeFFNER)
;Eingang 3 - AUX IN: E03 Steht Spindel?            1 = steht        (oeFFNER)
;Eingang 4 - AUX IN  E04 WZM-Eingefahren        1 = eingefahren        (oeFFNER)
;Eingang 5 - AUX IN: E05 WKZ gespannt?            1 = wkz eingelegt    (oeFFNER)
;Eingang 6 - AUX IN: E06 Spannzange Offen         1 = offen        (oeFFNER)

;Ausgaenge auf USB-CNC:
;
;Ausgang 1 - AUX OUT: A01 WZM-KLappe schliessen     1 = schliessen
;Ausgang 2 - AUX OUT: A02 WZM-Ausfahren            1 = ausfahren
;Ausgang 3 - AUX OUT: A03 Absaugung              1 = unten
;Ausgang 4 - AUX OUT: A04
;Ausgang 5 - AUX OUT: A05
;Ausgang 6 - AUX OUT: A06 Kegel Ausblasen        1 = ausblasen
;Ausgang 7 - AUX OUT: A07
;Ausgang 8 - AUX OUT: A08 Spannzange oeffnen        1 = oeffnen
;Ausgang 9 - AUX OUT: A09 

;***************************************************************************************
IF [#3500 == 0] ; INIT
    #3500 = 1
    M54 P1            ; A01 WZM-KLappe schliessen 1=geschlossen
    IF [#4511 == 0] THEN      
           #4511 =10    ; Freifahrhoehe        
    ENDIF
    IF [#4512 == 0] THEN      
        #4512 = 50      ; Antastgeschwindigkeit zum Taster "suchen"
    ENDIF  
    IF [#4513 == 0] THEN      
        #4513 =20      ; Tastgeschwindigkeit zum Messen
    ENDIF
    IF [#4510 == 0] THEN
        #4510 = 58.48 ; Hoehe des Werkzeugvermessungstasters
    ENDIF
    #4531 = 0 ; Zuruecksetzen der Config erfolgreich Variable

    ; Zuruecksetzen der Punktspeicher
    #100 = 0
WHILE [#100 <> 16]
        #[4540 + #100] = -10000000000
#100 = [#100 + 1]
    ENDWHILE
#100 = 0

;#5008 = 0 ;Zuruecksetzen der alten Werkzeugnummer, beim Start ist nie ein Werkzeug eingelegt

ENDIF
;***************************************************************************************
;---------------------------------------------------------------------------------------
Sub user_1 ; Spindel warmlaufen lassen um die Lager zu schonen
;---------------------------------------------------------------------------------------
;   #4532 Drehzahl Stufe 1 fuer Warmlauf Spindel
;   #4533 Laufzeit Stufe 1 fuer Warmlauf Spindel
;   #4534 Drehzahl Stufe 2 fuer Warmlauf Spindel
;   #4535 Laufzeit Stufe 2 fuer Warmlauf Spindel
;   #4536 Drehzahl Stufe 3 fuer Warmlauf Spindel
;   #4537 Laufzeit Stufe 3 fuer Warmlauf Spindel
;   #4538 Drehzahl Stufe 4 fuer Warmlauf Spindel
;   #4539 Laufzeit Stufe 4 fuer Warmlauf Spindel
Exec ".\\dialogBasic\\dialogBasic.exe" "-b=starten,abbrechen -r=1,0 -d=\"Soll die Spindel nun vorgewaermt werden?\"" 60000
msg "Return:"#5399
    IF [#5399 == 1]    ;OK
           G53 G00 Z0
        M03 S#4532
        G04 P#4533    
        M03 S#4534
        G04 P#4535    
        M03 S#4536
        G04 P#4537    
        M03 S#4538
        G04 P#4539    
        M05
    ENDIF
Endsub
;***************************************************************************************
Sub user_2; Spindel starten und Drehzahl setzen
;---------------------------------------------------------------------------------------
#1 = #5070 ; Abrufen der momentan Drehzahl der Spindel
Dlgmsg "Bitte neue Drehzahl der Spindel in rpm angeben:" "rpm" 1
    IF [#5398 == -1]
        msg "Das Setzen der Spindeldrehzahl wurde abgebrochen"
    ELSE
		#100 = #1
        msg "Neue Spindeldrehzahl "#100" rpm wurde gesetzt"
        S#100
		M3
    ENDIF
Endsub
;***************************************************************************************
Sub user_3 ; Werkzeugwechsel 
;---------------------------------------------------------------------------------------
#1 = 0
Dlgmsg "Welches Werkzeug soll eingewechselt werden" " Neue Werkzeugnr.:" 1    
    IF [#5398 == 1] ;OK
		#5011 = #1
        gosub change_tool
    ENDIF
Endsub
;***************************************************************************************
Sub user_4 ; Werkzeuglaengenmessung mithilfe des fest montierten Laengentasters
;---------------------------------------------------------------------------------------
    #5016 = [#5011]        ; Neue Werkzeugnummer
    #4527 = [0 - #4509]     ; Abstand Taster zum Spindelkopf  bei Z0 (G53)
    #5017 = [#4503]         ; Maximale Werkzeuglaenge
        #5019 = [#4507]         ; Werkzeuglaengensensorposition X-Achse
          #5020 = [#4508]         ; Werkzeuglaengensensorposition Y-Achse
          #5021 = 0         ; Gemessene Werkzeuglaenge wird hier eingetragen
    msg "Werkzeug wird vermessen"
    Exec ".\\dialogBasic\\dialogBasic.exe" "-b=starten,abbrechen -r=1,0 -d=\"Soll das Werkzeug nun vermessen werden?\"" 590000
	IF [[#5399 == 1] AND [#5397 == 0]] ;OK Taste wurde gedrueckt und RenderModus ist AUS !!
        IF [[#4527 + #5017 + 10] > [#4506]] THEN    ; Testen ob errechneter Wert hoeher wie sicherheitshoehe ist
            DlgMsg "Fatal: Werkzeug zu lang oder Config beschaedigt. Bei Bestaetigung mit OK wird die Werkzeuglaengenmessung neu gestartet"
            if [#5398 == 1] ;OK
                GoSub user_2
            ENDIF
        ENDIF
        G53 G0 z[#4506]                    ; Sicherheitshoehe 
           G53 G0 x[#5019] y[#5020] ; Fahren ueber die Position des festen Laengentasters
        G53 G0 z[#4527 + #5017 + 10]
        G53 G38.2 Z[#4527] F50
        IF [#5067 == 1]                    ; Wenn Sensor gefunden wurde
             G91 G38.2 Z20 F20
             G90
                IF [#5067 == 1]                ; Wenn Sensor gefunden wurde, wird Tastpunkt in #5053 gespeichert
                G0 G53 z#4506 ;Anfahren der Sicherheitshoehe
                ;***********Bei Direktvermessung Tabelle auf 0 schreiben
                msg "Zuruecksetzen des Tools mit der Nr: "#5016
                #[5400 + #5016] = 0 ;Zuruecksetzen des Z-Offsets des neuen Werkzeuges
                #[5500 + #5016] = 0 ;Zuruecksetzen des Durchmessers des neuen Werkzeuges

                #5021 = [#5053 - #4527]        ; Berechnung Werkzeuglaenge = Tastpunkt  - chuck height
                    msg "Werkzeuglaenge des neuen Werkzeuges: " #5021
                ;Schreiben des neuen Werkzeuges in die Tool Tabelle
                
DlgMsg "Bitte geben sie einen Werkzeugdurchmesser ein oder brechen ab" "Werkzeugdurchmesser mm" 1
if [#5398 == 1] ;OK
    IF [#1 <= 0]
        warnmsg "Werkzeugdurchmesser mit kleiner gleich 0 ist nicht erlaubt"
    ELSE
        #[5500 + #5016] = #1
    ENDIF
ENDIF
                #[5400 + #5016] = #5021 ; Setzen der Kompensation fuer das Werkzeug
              ELSE
                    errmsg "FEHLER: Der stationaere Taster hat nicht geschaltet"
            ENDIF
        ELSE
            errmsg "FEHLER: Der stationaere Taster hat nicht geschaltet"
        ENDIF
    ENDIF    
Endsub
;***************************************************************************************
Sub user_5 ; Messung der Einspannlaenge des 3D-Tasters (nur Z-Koordinate)
;---------------------------------------------------------------------------------------
    #5021 = 0 ; Z Position des Laengensensors bei Beruehrung
    #4530 = 264.4 ; Fester Wert, gemessen am 05.05.2019, Hoerauf
    IF [#4531 == 1] ; pruefe ob config schon mal gesetzt wurde
    Exec ".\\dialogBasic\\dialogBasic.exe" "-b=Ja,Nein -r=1,0 -d=\"Die aktuelle Position wird für Antasten der Z-Hoehe genutzt. Abbrechen, falls nicht.\"" 600000
G21 ; "Umstellen" der Einheit in mm (eigentlich sollte niemals etwas anderes eingestellt sein)
G94 ; Setze Feed Rate auf Units/min (Standard zum Fraesen)
    if [#5399 == 1] ; OK gedrueckt
        msg "3D-Taster faehrt nun maximal 25mm in Richtung Tisch"    
        G38.2 G91 z-25 F50;         Anfahren auf Taster bis Schaltsignalaenderung
        IF [#5067 == 1]                    ; 3D-Taster ausgeloest
            G38.2 G91 z20 F20        ; Langsam von Taster runterfahren zur exakten Z-Ermittlung
            IF [#5067 == 1]                ; 3D-Taster ausgeloest
                #4529 = [#4530 + #5053] ; Bestimme 3D-Tasterlaenge (Positiver Abstand Tisch zu z0 + Z-Koordinate (negativ) an der der Taster zuletzt geschaltet hat)
                G91 F100 Z5         ; 3D-Taster 25mm freifahren
                msg "Aktuelle Einspannlaenge des 3D-Tasters ermittelt:"#4529"mm"
            ELSE
                errmsg "FEHLER: 3D-Taster hat nicht geschaltet!"
            ENDIF
        ELSE
            errmsg "FEHLER: 3D-Taster hat nicht geschaltet!"
        ENDIF
    ELSE
        msg "Das Einmessen des 3D-Tasters wurde abgebrochen"
    ENDIF
ELSE
    ; config und damit Abstand Spindelnase <-> Tisch nicht gesetzt - keine Laengenmessungen moeglich!
    errmsg "Abbruch des Einmessens, da config nicht gesetzt ist."
    ENDIF
    G90
Endsub
;***************************************************************************************
Sub user_6 ; Antasten eines Werkstueckes in X und Y Koordinate oder Nullsetzen der Z-Koordinate auf die Werkstueckoberflaeche
;_______________________________________________________________________________________
msg "Folgende Annahmen muessen durch das Werkstueck erfuellt sein"
msg "Werkstueck befindet sich planparallel zur XY Ebene"
msg "Werkstueck beinhaltet ein rechtwinkliges Dreieck"
msg "Der zu messende Werkstuecknullpunkt liegt in der Ecke mit dem 90°-Winkel"
msg "Die zwei zu messenden Strecken sind gerade schneiden sich im 90°Winkel"
msg "Z-Antasten sollte ueber einer in der XY-Ebene flachen Stelle des Werkstuecks erfolgen - Die Z-Koordinate wird auf die Oberflaeche null-gesetzt"

Exec ".\\dialogBasic\\dialogBasic.exe" "-b=Ja,Nein -r=1,0 -d=\"Sind die Annahmen zu dem Werkstueck erfuellt (siehe Textkonsole)?\"" 600000
IF [#5399 == 1] ;OK
    #1 = 1000;X Wert von Punkt 1
    #2 = 1000;Y Wert von Punkt 1
    #3 = 1000;X Wert von Punkt 2
    #4 = 1000;Y Wert von Punkt 2
    #5 = 1000;X Wert von Punkt 3
    #6 = 1000;Y Wert von Punkt 3
    #25 = 0;Auswahl
    
    #100 = 0
    #101 = -1
    WHILE [#100 <> 16]
        msg "Suche an Adr:"[4540 + #100]" Wert:"[#[4540 + #100]]
        IF [[#[4540 + #100] <> -10000000000] AND [#[4540 + #100 + 1] <> -10000000000]]
            ;Gueltiger Punkt wurde gefunden
            #101 = [4540 + #100] ; Index des ersten gueltigen Punktes
            #100 = 16
        ELSE
            #100 = [#100 + 2]
        ENDIF
    ENDWHILE
    msg "Gueltigen Punkt an Position: "#101" gefunden"
    IF [[#101 - 4540] == 14]
        ;Das Wrap Around bei den Punkten 7,8 und Punkt 1 wird noch nicht unterstuetzt
        errmsg "Das warp around der Punkte 7 und 8 in Kombination mit Punkt 1 wird noch nicht unterstuetzt. Bitte waehlen Sie eine andere Kombination von Punkten"
    ENDIF
    #100 = 0

    WHILE [#100 <> 6]
        IF [[#[#101 + #100] <> -10000000000] AND [#[#101 + #100 + 1] <> -10000000000]]
        ;Gueltiger Punkt wurde gefunden
        #[1 + #100] = #[#101 + #100]
        #[2 + #100] = #[#101 + #100 + 1]
        #103 = 1 ;Es wurden drei auf. folg. Punkte gefunden
        #100 = [#100 + 2]
ELSE
    #103 = 0 ;Es wurden keine drei aufeinanderfolgende gueltige Punkte gefunden
    #100 = 6 ; Abbruch der Schleife
ENDIF
    ENDWHILE

    IF [#103 == 1]
        msg "Drei gueltige Punkte von Position: "#101" an gefunden"
ELSE
    #101 = 4540
ENDIF
#101 = [[#101 - 4540] / 2]
    
    LogFile ".\\dialogPoints\\callparameter.txt" 0
    LogMsg "-p=X"#4540"Y"#4541",x"#4542"y"#4543",x"#4544"y"#4545",x"#4546"y"#4547",x"#4548"y"#4549",x"#4550"y"#4551",x"#4552"y"#4553",x"#4554"y"#4555
    Exec ".\\dialogPoints\\CNC.exe" "-f .\\dialogPoints\\callparameter.txt" 600000
#25 = #5399

IF [#25 <> 0] ;OK
        IF [[#25 > 15] OR [#25 < 24]]
#25 = [#25 - 15]
        ; Punkt XY soll gesetzt werden
        ; Funktionsaufruf m503
        ; Bearbeiten der Rueckgabeparameter

        #104 = 0; A Parameter von m503 aufruf
        #105 = 10; B Parameter von m503 aufruf
        IF [[#25 == 1] OR [#25 == 2] OR [#25 == 5] OR [#25 == 6]]
            ; Verfahren in X-Richtung
            #104 = 1
        ELSE 
            ; Verfahren in Y-Richtung
            #104 = 3
        ENDIF 
        IF [#25 < 5]
            ; positive Verfahrrichtung
            #104 = [#104 + 0]
        ELSE 
            ; negative Verfahrrichtung
            #104 = [#104 + 1]
        ENDIF
        M503 A[#104] B[#105]

#[4540 + [#25 * 2]]  = #300 ; Setzen des X-Wertes aus der Rueckgabe
#[4540 + [#25 * 2] + 1]  = #301 ; Setzen des Y-Wertes aus der Rueckgabe
ENDIF
        IF [#25 == 48]
; Funktionsaufruf Z Werkstueck messen und auf B setzen
M504 A[#105] B[0]
        ENDIF
        IF [[#25 > 31] OR [#25 < 40]]
            ; Punkt XY soll geloescht werden
            #[4540 + [ #25-11] * 2] = -10000000000        ; X
            #[4540 + [[#25-11] * 2] +1] = -10000000000  ; Y
            msg "Punkt "[#25-10]" wurde geloescht"
        ENDIF
        IF [#25 == 80]
            ; alle gespeicherten Punkte loeschen
            #106 = 0
    WHILE [#106 < 16]
        #[4540 + #106] = -10000000000
    ENDWHILE
    msg "alle Koordinatenpunkte aus dem Speicher geloescht"
ENDIF
        IF [#25 == 64]
            ; Berechnung mit den eingegebenen Punkten
            IF [#103 == 1]
                ;Berechnung des Winkels der Strecke der niedrigeren Punkte (z.B. P1, P2) gegenueber der X bzw. Y Achse
                M500 A[4540 + [#101 * 2]]  B[4540 + [#101 * 2]] C[4540 + [[#101 + 1] * 2]]  D[4540 + [[#101 + 1] * 2 ]]]  E0 F0 G0 H1
                #107 = #5399 ;Der Winkel zwischen den ersten beiden Punkten und der Y-Achse
M500 A[4540 + [#101 * 2]]  B[4540 + [#101 * 2]] C[4540 + [[#101 + 1] * 2]]  D[4540 + [[#101 + 1] * 2 ]]]  E0 F0 G1 H0
                #108 = #5399 ;Der Winkel zwischen den ersten beiden Punkten und der X-Achse
                IF [#108 >= #107]
                    #107 = #108 ; #107 enthaelt nun den passenden Drehwinkel
                ENDIF
                ;Berechnung des Werkstuecknullpunktes (eingeschlossener Punkt zwischen Gerade und Punkt)
                M502 A[4540 + [#101 * 2]]  B[4540 + [#101 * 2]] C[4540 + [[#101 + 1] * 2]]  D[4540 + [[#101 + 1] * 2 ]]] E[4540 + [[#101 + 2] + 1]]  F[4540 + [[#101 + 2] * 2 ]]
                #109 = #301 ;Werkstuecknullpunktes X
                #110 = #302 ;Werkstuecknullpunktes Y
                msg "Berechnete Korrektur, X: "#109" Y: "#108", Rotation: "#107
                G92 X[#109 * -1] Y[#110 * -1] ; Verschieben des Werkstuecknullpunktes in den Koordinatenursprung
                G68 X0 Y0 R[#107 * -1]; Rotation um den Koordinatenursprung
            ELSE
                Exec ".\\dialogBasic\\runIt.bat" ".\\dialogBasic\\dialogBasic.exe -b=Ja,Nein -r=1,0 -d=\"Es wurden nicht alle benoetigten Punkte eingegeben. Bitte ergaenzen Sie notwendige Punkte\"" 600000
            ENDIF
ENDIF
ENDIF
ENDIF
ENDSUB
;***************************************************************************************
Sub user_8 ; Antasten eines Innenkreises/einer Kreistasche und setzen des XY-Nullpunktes in die Mitte der Kreistasche
    msg "hier kommt die Innenkreisantastfunktion hin"
EndSub
;***************************************************************************************
Sub user_9 ; Antasten eines Aussenkreises/ Rundmaterialstuecks das senkrecht auf der XY-Ebene steht (XY-Null == Mittelpunkt)
	msg "hier kommt die Aussenkreistastfunktion hin"
EndSub
;***************************************************************************************
Sub user_10 ; Reset der Koordinatenrotation in der XY-Ebene
;---------------------------------------------------------------------------------------
    Exec ".\\dialogBasic\\dialogBasic.exe" "-b=Ja,Nein -r=1,0 -d=\"Soll die Rotation des aktuellen Koordinatensystems auf 0 Grad zurückgesetzt werden??\"" 600000
    if [#5399 == 1] ;OK
        G69 R0
    ENDIF
Endsub

;***************************************************************************************
Sub home_z ;Homing per axis
;---------------------------------------------------------------------------------------
    msg "Referenziere Achse Z"
    M80
    g4p0.2
    home z
Endsub
;***************************************************************************************
Sub home_x
    msg "Referenziere Achse  X"
    M80
    g4p0.2
    home x
    ;homeTandem X
Endsub
;***************************************************************************************
Sub home_y
    msg "Referenziere Achse  Y"
    M80
    g4p0.2
    home y
    ;homeTandem Y
Endsub
;***************************************************************************************
Sub home_a
    msg "Referenziere  Achse A"
    M80
    g4p0.2
    home a
Endsub
;***************************************************************************************
Sub home_b
    msg "Referenziere  Achse  B"
    M80
    g4p0.2
    home b
Endsub
;***************************************************************************************
Sub home_c
    msg "Referenziere  Achse  C"
    M80
    g4p0.2
    home c
Endsub
;***************************************************************************************
;Home all axes
sub home_all
    gosub home_z
    gosub home_y
    gosub home_x
    gosub home_a
    G53 G01 X0 Y-600 Z0 A0 F1000; Achse X, Y und Z auf 0 Fahren    
    msg"Referenzierung fertig"    
    ;homeIsEstop on ;diese Zeile Einkommentieren wenn Refschalter = Endschalter  
    m30
endsub

;***************************************************************************************
Sub zero_set_rotation
;---------------------------------------------------------------------------------------
    msg "Ersten Punkt antasten und mit STRG + G fortfahren"
    m0
    #5020 = #5071 ;x1
    #5021 = #5072 ;y1
    msg "Zweiten Punkt antasten und mit STRG + G fortfahren"
    m0
    #5022 = #5071 ;x2
    #5023 = #5072 ;y2
    #5024 = ATAN[#5023 - #5021]/[#5022 - #5020]
    if [#5024 > 45]
       #5024 = [#5024 - 90] ;Punkte in Y Achse
    endif
    g68 R#5024
    msg "Koordinatensystem mit G68 R"#5024" gedreht"
    msg " Bitte STRG + G druecken zum abschliessen"
Endsub

;***************************************************************************************
sub change_tool
;---------------------------------------------------------------------------------------
M5
M9            
G4P1 ; Warte 1s damit die Spindel auslaufen kann
    
    #100 = 1 ; Werkzeug soll gewechselt werden! - 1 = ja
    IF [[#5011] == [#5008]] THEN
		Exec ".\\dialogBasic\\dialogBasic.exe" "-b=Ja,Nein -r=1,0 -d=\"Werkzeug bereits eingelegt. Trotzdem wechseln?\""
        if [#5399 == 1] ; OK
            #100 = 1
        ELSE
            #100 = 0
        ENDIF
    ENDIF

    IF [#100 == 1] THEN
		IF [#5011 > 99] THEN
                Dlgmsg "Werkzeugnr Ungueltig: Bitte Werkzeugnummer 1..99 Auswaehlen. Bei Betaetigung von OK wird der Werkzeugwechsel erneut durchgefuehrt" 
                if [#5398 == 1] ;OK
                    gosub change_tool
                ELSE
                    warnmsg "Werkzeugwechsel abgebrochen"
            ENDIF
		ENDIF
		 G53 G0 Z[#4523] ; Sicherheitshoehe
        G53 G0 X[#4521] ; Werkzeugwechselpos X
        M54 P1; AUX1 an
		#1 = #5008
		#2 = #5011
        Dlgmsg "Folgende Werkzeugnummern wurden erfasst. Bitte mit OK bestaetigen" "Wz alt:" 1 "Wz neu" 2
		msg "Bitte schliessen Sie die Tuer und druecken Sie STRG+G nach dem Werkzeugwechsel um fortzufahren"
        IF [#5398 == 1] ;OK
			msg "Werkzeugnr.: " #5008" mit Werkzeugnr.: " #5011 " gewechselt"
			m6t[#5011]
			IF [#5011 <> 0]
				G43 H[#5011]
			ENDIF
        ELSE
            warnmsg "Werkzeugwechsel abgebrochen"
        ENDIF
        M55 P1; AUX1 aus
    ELSE
        warnmsg "Es wurde kein Werkzeug gewechselt"
ENDIF
ENDSUB
;***************************************************************************************
sub config
;---------------------------------------------------------------------------------------
IF [#4531 == 1] 
    Dlgmsg "Es wurde bereits eine Konfiguration hinterlegt. Umschreiben?"
ENDIF
if [#5398 == 1] ;OK
    msg "Die Konfiguration wird nun neu gesetzt"
gosub config_alg
GoSub wzwp
GoSub wlmp
GoSub SPWL
#4531 = 1
ELSE
    msg "Die Konfiguration wurde nicht veraendert"
ENDIF
endsub

;***************************************************************************************
sub config_alg
	#1 = #4530
    Dlgmsg "Abstand HSK-Schaft zu Tischplatte in mm (#1):" "1" 4530
	if [#5398 == 1] THEN
		if [#1 < 0 ] THEN
			Dlgmsg "Keine neg. Werte fuer Abstand. Erneut durchlaufen?"
			if [#5398 == 1] ;OK
				gosub config
			ELSE
				msg "Konfiguration wird nicht erneut durchlaufen"
			ENDIF
		ELSE
			#4530 = #1
		ENDIF
	ENDIF
endsub

;***************************************************************************************
sub WZWP
;---------------------------------------------------------------------------------------
;0= Mache garnix 1 = Nur WPos Anfahren 2= WPos anfahren  + Vermessen
#1 = 0
Dlgmsg "Bitte Werkzeugwechslertyp eingeben" "TYP" 1 
if [#5398 == 1] ;OK
	#4520 = #1
    IF [#4520 > 0 ] THEN
        ;Dlgmsg "Bitte Werkzeugwechselposition eingeben" "Position X-Achse" 4521 "Position Z-Achse" 4523
        Dlgmsg "Bitte Werkzeugwechselposition eingeben" "posXAxis" 4521 "posZAxis" 4523
    ENDIF
ENDIF
endsub
;***************************************************************************************

;***************************************************************************************
sub WLMP
;---------------------------------------------------------------------------------------
Dlgmsg "Bitte Werkzeuglaengensensordaten eingeben" "Position X-Achse" 4507 "Position Y-Achse" 4508 "Sicherheitshoehe Z" 4506 "Max. Werkzeuglaenge" 4503

; Berechnung Z Abstand zwischen HSK Schaft und Werkzeugvermessungstaster Ausloesepunkt
#4509 = [#4530 - #4510]
    IF [#4509 < 0 ] THEN
        errmsg "Der Wert #4509 (Abstand zwischen HSK Schaft und Werkzeugvermessungstaster Ausloesepunkt) wurde falsch berechnet. Er ist negativ! Bitte #4530 und #4510 pruefen"
        gosub config
    ENDIF
    IF [#4509 < [#4503 + 10]] THEN
        errmsg "Der Abstand zwischen HSK Schaft und Werkzeugvermessungstaster Ausloesepunkt ist kleiner als die maximal erlaubte Werkzeuglaenge (#4503). Bitte ueberpruefen Sie den Wert."
        gosub config
    ENDIF
endsub
;***************************************************************************************


;***************************************************************************************
sub SPWL
;---------------------------------------------------------------------------------------
;   #4532 Drehzahl Stufe 1 fuer Warmlauf Spindel
;   #4533 Laufzeit Stufe 1 fuer Warmlauf Spindel
;   #4534 Drehzahl Stufe 2 fuer Warmlauf Spindel
;   #4535 Laufzeit Stufe 2 fuer Warmlauf Spindel
;   #4536 Drehzahl Stufe 3 fuer Warmlauf Spindel
;   #4537 Laufzeit Stufe 3 fuer Warmlauf Spindel
;   #4538 Drehzahl Stufe 4 fuer Warmlauf Spindel
;   #4539 Laufzeit Stufe 4 fuer Warmlauf Spindel
    Dlgmsg "Spindelwarmlaufparameter" "Drehzahl Stufe 1" 4532 "Laufzeit (sek.) Stufe 1" 4533 "Drehzahl Stufe 2" 4534 "Laufzeit(sek.) Stufe 2" 4535 "Drehzahl Stufe 3" 4536 "Laufzeit (sek.) Stufe 3" 4537 "Drehzahl Stufe 4" 4538 "Laufzeit(sek.) Stufe 4" 4539
ENDSUB


;***************************************************************************************
sub zhcmgrid
;***************************************************************************************
;probe scanning routine for uneven surface milling
;scanning starts at x=0, y=0

  if [#4100 == 0]
   #4100 = 10  ;nx
   #4101 = 5   ;ny
   #4102 = 40  ;max z 
   #4103 = 10  ;min z 
   #4104 = 1.0 ;step size
   #4105 = 100 ;probing feed
  endif    

  #110 = 0    ;Actual nx
  #111 = 0    ;Actual ny
  #112 = 0    ;Missed measurements counter
  #113 = 0    ;Number of points added

  ;Dialog
  dlgmsg "gridMeas" "nx" 4100 "ny" 4101 "maxZ" 4102 "minZ" 4103 "gridSize" 4104 "Feed" 4105 
    
  if [#5398 == 1] ; user pressed OK
    ;Move to startpoint
    g0 z[#4102];to upper Z
    g0 x0 y0 ;to start point
        
    ;ZHCINIT gridSize nx ny
    ZHCINIT [#4104] [#4100] [#4101] 
    
    #111 = 0    ;Actual ny value
    while [#111 < #4101]
      #110 = 0
      while [#110 < #4100]
        ;Go up, goto xy, measure
        g0 z[#4102];to upper Z
        g0 x[#110 * #4104] y[#111 * #4104] ;to new scan point
        g38.2 F[#4105] z[#4103];probe down until touch
                
        ;Add point to internal table if probe has touched
        if [#5067 == 1]
          ZHCADDPOINT
          msg "nx="[#110 +1]" ny="[#111+1]" added"
          #113 = [#113+1]
        else
          ;ZHCADDPOINT
          msg "nx="[#110 +1]" ny="[#111+1]" not added"
          #112 = [#112+1]
        endif

        #110 = [#110 + 1] ;next nx
      endwhile
      #111 = [#111 + 1] ;next ny
    endwhile
        
    g0 z[#4102];to upper Z
    ;Save measured table
    ZHCS zHeightCompTable.txt
    msg "Done, "#113" points added, "#112" not added" 
        
  else
    ;user pressed cancel in dialog
    msg "Operation canceled"
  endif
endsub

;***************************************************************************************
; Handradfunktionen
;---------------------------------------------------------------------------------------
;***************************************************************************************
 SUB xhc_probe_z ;Z-Nullpunktermittlung
;---------------------------------------------------------------------------------------
    #3505 = 1                    ; Merker ob Laengenmessung von Handrad 1=Handrad
    gosub user_1 ;Z-Nullpunktermittlung
ENDSUB

;***************************************************************************************
SUB xhc_macro_1
;---------------------------------------------------------------------------------------
    msg"Keine Funktion fuer Macro 1 Hinterlegt"
ENDSUB

;***************************************************************************************
SUB xhc_macro_2
;---------------------------------------------------------------------------------------
    gosub user_2 ;Werkzeugvermessung
ENDSUB
;***************************************************************************************
SUB xhc_macro_3
;---------------------------------------------------------------------------------------
    msg"Keine Funktion fuer Macro 3 Hinterlegt"
ENDSUB
;***************************************************************************************
SUB xhc_macro_6
;---------------------------------------------------------------------------------------
    msg"Keine Funktion fuer Macro 6 Hinterlegt"
ENDSUB
;***************************************************************************************
SUB xhc_macro_7
;---------------------------------------------------------------------------------------
    msg"Keine Funktion fuer Macro 7 Hinterlegt"
ENDSUB

;
; Die folgenden Funktionen sind auf freie Register im Bereich #100-#299 angewiesen
;
;

sub m501
; Atan2 function
; Parameter X und Y in Benutzung
; Rueckgabe ueber #5399
    msg "Call of m501 with X ="#24" and Y = "#25
    if [#24 == -10000000000] ; Check for set value
        errmsg "Parameter X is not set at function call m501"
    endif
    if [#25 == -10000000000] ; Check for set value
        errmsg "Parameter Y is not set at function call m501"
    endif
    if [#24 > 0] THEN
        #5399 = ATAN[#25]/[#24] 
    endif
    if [#24 == 0] THEN
        if [#25 == 0] THEN
            errmsg "Parameter X and Y is zero, so m501 is undefined"
            #5399 = -10000000000
        endif
        if [[#25] > 0] THEN
            #5399 =  1.57079632679
        endif        
        if [[#25] < 0] THEN
            #5399 =  -1.57079632679
        endif
    endif
    if [[#25] >= 0] THEN
        if [[#24] < 0] THEN
            #5399 = [ATAN[#25]/[#24] +  3.14159265359]
        endif
    endif
    if [[#25] < 0] THEN
        if [[#24] < 0] THEN
            #5399 = [ATAN[#25]/[#24] -  3.14159265359]
        endif
    endif
endsub

sub m500
; CalcAngleWithFourPoints
; A=AX B=AY C=BX D=BY E=CX F=CY G=DX H=DY
; Diese Funktion berechnet den Winkel zwischen zwei Geraden
msg "Call of m500 with A ="#1" and B = "#2" and C = "#3" and D = "#4" and E = "#5" and F = "#6" and G = "#7" and H = "#8
#201 = #1
#202 = #2
#203 = #3
#204 = #4
#205 = #5
#206 = #6
#207 = #7
#208 = #8

#100 = [#206 - #202]; CY - AY
#101 = [#205 - #201]; CX - AX
m501 X#101 Y#100
#105 = #5399 ;Store value
msg "Call of m501 (ext) with X ="#101" and Y = "#100", result: "#5399

#103 = [#208 - #204]; DY - BY
#104 = [#207 - #203]; DX - BX
msg "#103:"#103"#104:"#104
m501 X#104 Y#103
msg "Call of m501 (ext) with X ="#104" and Y = "#103", result: "#5399

#106 = #5399 ;Store value

#5399 = [#106 - #105]
endsub

sub m502
; CalcPoint of intersection between Point and line
; A=A0 B=B0 C=c D=PX E=PY
; a0 * x + b0 * y +c = 0
; P(PX, PY)
; Gibt Werte in #301 und #302 zurueck
msg "A0:"#1"B0:"#2"C:"#3"X:"#4"Y:"#5
#6 = [-1 * [#1 * #4 + #2 * #5 + #3]]
#7 = [#1 * #1 + #2 * #2]
#6 = [#6 / #7] ;-1 * (a * x1 + b * y1 + c) / (a * a + b * b)
#301 = [#6 * #1 + #4]; #6 * a + x1
#302 = [#6 * #2 + #5]; #6 * b + y1
endsub

Sub m503 ; Anfahren eines Werkstuecks bis der Taster ausloest
; Parameter A=Anfahrrichtung (1=+X, 2=-X, 3=+Y, 4=-Y)
; Parameter B=Maximaler Anfahrweg
; Rueckgabe des X und Y Wertes ueber die Register 301 und 302
IF [[#1 > 4] OR [#1 < 1]]
    DlgMsg "Interner Fehler! Das Macro m503 wurde mit einer ungueltigen Anfahrrichtung ausgefuehrt
ELSE
IF [[#2 > 25] OR [#2 < 0]]
    DlgMsg "Interner Fehler! Das Macro m503 wurde mit einem ungueltigen Anfahrweg ausgefuehrt
ELSE
    ;Hier kommt die eigentliche Funktion
msg "Bitte fahren Sie den 3D-Taster in die Naehe des anzutastenen Punktes. Der maximale Abstand darf:"#2" mm betragen und bestaetigen dann mit der Tastenkombination STRG + G"
m0
    IF [#1 MOD 2 == 0] ; Pruefen ob eine negative Bewegung vorliegt
        #2 = -#2
ENDIF
    IF [[#1 == 1] OR [#1 == 2]] ; Antastung mit Bewegung entlang der X-Achse
G91 G38.2 x[#2] F50
    IF [#5067 == 1]                    ; Wenn Sensor gefunden wurde
        #3 = [-#2 / 2]
        G91 G38.2 x#3 F20
        IF [#5067 == 1]                ; Wenn Sensor gefunden wurde
            #301 = #5061
            #302 = #5062
        ENDIF
    ELSE
        DlgMsg "FEHLER: 3D-Taster wurde nicht ausgeloest. Wiederholen?"
        IF [#5398 == 1] ;OK
        m503 A[#1] B[#2]
    ENDIF
    ENDIF 
        ELSE ; Antastung mit Bewegung entlang der Y-Achse
G91 G38.2 y[#2] F50
    IF [#5067 == 1]                    ; Wenn Sensor gefunden wurde
        #3 = [-#2 / 2]
        G91 G38.2 y#3 F20
        IF [#5067 == 1]                ; Wenn Sensor gefunden wurde
            #301 = #5061
            #302 = #5062
        ENDIF

    ELSE
        DlgMsg "FEHLER: 3D-Taster wurde nicht ausgeloest. Wiederholen?"
        IF [#5398 == 1] ;OK
        m503 A[#1] B[#2]
    ENDIF
    ENDIF 
    ENDIF
ENDIF
ENDIF
ENDSUB

Sub M504 ; Z-Antasten an aktueller Position, keine Rueckgabe von Werten nur Z-Setzen auf angegeben Wert
; Parameter A = maximale Entfernung die der Taster beim Tasten zuruecklegt
; Parameter B = Wert auf den die Werkstueckkoordinate Z nach dem Tasten gelegt wird
    IF [#1 < 0]
        errmsg "Ein Abstand darf nicht negativ werden - Sinn??"
    ELSE
        G91 G38.2 Z-#1 F50                ; fahre maximal #1 mm nach unten bis der Taster ausloest
    IF [#5067 == 1]                    ; Taster ausgeloest
        G91 G38.2 Z#1 F20                ; Taster freifahren
        IF [#5067 == 1]                ; Taster ausgeloest
            G92 Z#2                ; Z-Koordinate auf #2 setzen
            G91 G1 F100 Z10            ; bissl wegfahren vom Beruehrpunkt
            msg "Z tasten erfolgreich, auf Z="#2" mm gesetzt"
        ENDIF
    ELSE
        errmsg "Taster konnte nicht ausloesen - Entfernung zum Werkstueck ueberschritten?"
    ENDIF
    ENDIF
    G90 ; absolute Koordinaten wieder aktivieren
ENDSUB

