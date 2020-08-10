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
; 	#3N00---3N99 reserviert fuer msg50N
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
;   #4555 Ende des Speicherplatzes zu obiger Zeile
; 	#4556 Start des Punktspeichers Kreis
;	#4563 Ende des Punktespeichers
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
        G53 G38.2 Z[#4527] F100
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
    #25 = 0;Auswahl
    
    #100 = 0
    #101 = -1
    WHILE [#100 <> 16]
        msg "Suche an Adr:"[4540 + #100]" Wert:"[#[4540 + #100]]
        IF [[#[4540 + #100] <> -10000000000] AND [#[4540 + #100 + 1] <> -10000000000]]
            ;Gueltiger Punkt wurde gefunden
            #101 = [4540 + #100] ; Index des ersten gueltigen Punktes
			msg "Gueltigen Punkt an Position: "#101" gefunden"
            #100 = 16
        ELSE
            #100 = [#100 + 2]
        ENDIF
    ENDWHILE
    
    IF [[#101 - 4540] == 14]
        ;Das Wrap Around bei den Punkten 7,8 und Punkt 1 wird noch nicht unterstuetzt
        errmsg "Das warp around der Punkte 7 und 8 in Kombination mit Punkt 1 wird noch nicht unterstuetzt. Bitte waehlen Sie eine andere Kombination von Punkten"
    ENDIF
    #100 = 0
	
	IF [#101 <> -1]
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
	ENDIF
    IF [#103 == 1]
        msg "Drei gueltige Punkte von Position: "#101" an gefunden"
ELSE
    #101 = 4540
ENDIF
#101 = [[#101 - 4540] / 2]
    msg "Berechneter Punkteoffset: "#101
	msg "Punkt A: "[#[4540 + [#101 * 2]]]
	msg "Punkt B: "[#[4541 + [#101 * 2]]]
	msg "Punkt C: "[#[4542 + [#101 * 2]]]
	msg "Punkt D: "[#[4543 + [#101 * 2]]]
	msg "Punkt E: "[#[4544 + [#101 * 2]]]
	msg "Punkt F: "[#[4545 + [#101 * 2]]]
    LogFile ".\\dialogPoints\\callparameter.txt" 0
    LogMsg "-p=X"#4540"Y"#4541",x"#4542"y"#4543",x"#4544"y"#4545",x"#4546"y"#4547",x"#4548"y"#4549",x"#4550"y"#4551",x"#4552"y"#4553",x"#4554"y"#4555
    Exec ".\\dialogPoints\\CNC.exe" "-f .\\dialogPoints\\callparameter.txt" 600000
	#25 = #5399
	msg "Return value from dialog: "#5399

	IF [#25 <> 0] ;OK
        IF [[#25 > 15] AND [#25 < 24]]
			#111 = [#25 - 16] ; Rueckgabe des Punktes im Bereich 1-8
			; Punkt XY soll gesetzt werden
			; Funktionsaufruf m503
			; Bearbeiten der Rueckgabeparameter

			#104 = 0; A Parameter von m503 aufruf
			#105 = 10; B Parameter von m503 aufruf
			IF [[#111 == 1] OR [#111 == 2] OR [#111 == 5] OR [#111 == 6]]
				; Verfahren in X-Richtung
				#104 = 1
			ELSE 
				; Verfahren in Y-Richtung
				#104 = 3
			ENDIF 
			IF [#111 < 5]
				; positive Verfahrrichtung
				#104 = [#104 + 0]
			ELSE 
				; negative Verfahrrichtung
				#104 = [#104 + 1]
			ENDIF
			M503 A[#104] B[#105]
			IF [#5399 == 1] ; Return value 
				#111 = [#111 - 1] ; Indizierung mit Index 0 - 1
				msg "Setze Punkt an Addr: "[4540 + [#111 * 2]]
				#[4540 + [#111 * 2]]  = #3303 ; Setzen des X-Wertes aus der Rueckgabe
				#[4540 + [#111 * 2] + 1]  = #3304 ; Setzen des Y-Wertes aus der Rueckgabe
			ENDIF
		ENDIF
        IF [#25 == 48]
			;Funktionsaufruf Z Werkstueck messen und auf B setzen
			#105 = 10; B Parameter von m503 aufruf
			M504 A[#105] B[#4529]
        ENDIF
        IF [[#25 > 31] AND [#25 < 40]]
            ; Punkt XY soll geloescht werden
            #[4540 + [ #25-11] * 2] = -10000000000        ; X
            #[4540 + [[#25-11] * 2] +1] = -10000000000  ; Y
            msg "Punkt "[#25-10]" wurde geloescht"
        ENDIF
        IF [#25 == 80]
            ; alle gespeicherten Punkte loeschen
            #106 = 0
			WHILE [#106 <> 16]
				#[4540 + #106] = -10000000000
				#106 = [#106 +1]
			ENDWHILE
			msg "alle Koordinatenpunkte aus dem Speicher geloescht"
		ENDIF
        IF [#25 == 64]

			#107 = -10000000000		
			#108 = -10000000000	
            ; Berechnung mit den eingegebenen Punkten
            IF [#103 == 1]
                ;Berechnung des Winkels der Strecke der niedrigeren Punkte (z.B. P1, P2) gegenueber der X bzw. Y Achse
                M500 A[#[4540 + [#101 * 2]]]  B[#[4541 + [#101 * 2]]] C[#[4542 + [[#101] * 2]]]  D[#[4543 + [[#101] * 2]]]  E[#[4542 + [[#101] * 2]]] F[#[4543 + [[#101] * 2]]] G[[#[4542 + [[#101] * 2]]]+100] H[#[4543 + [[#101] * 2]]]
                IF [#5399 <> -10000000000]
					msg "Winkelberechnung 1 erfolgreich"
					#107 = #5399 ;Der Winkel zwischen den ersten beiden Punkten und der Y-Achse
				ENDIF
				M500 A[#[4540 + [#101 * 2]]]  B[#[4541 + [#101 * 2]]] C[#[4542 + [[#101] * 2]]]  D[#[4543 + [[#101] * 2]]]  E[#[4542 + [[#101] * 2]]] F[#[4543 + [[#101] * 2]]] G[#[4542 + [[#101] * 2]]] H[[#[4543 + [[#101] * 2]]]+100]
				IF [#5399 <> -10000000000]
					msg "Winkelberechnung 2 erfolgreich"
					#108 = #5399 ;Der Winkel zwischen den ersten beiden Punkten und der X-Achse
				ENDIF
				IF [[#107 <> -10000000000] AND [#108 <> -10000000000]]
						IF [#108 >= #107]
							#107 = #108 ; #107 enthaelt nun den passenden Drehwinkel
						ENDIF
				ELSE
					IF [#108 <> -10000000000]
						#107 = #108
					ENDIF
				ENDIF
				IF [#107 <> -10000000000]
					;Umrechnen von #107 (Winkeldrehung in Grad)
					#107 = [#107 * 57.2958]
					WHILE [#107 >= 90.0]
						#107 = [#107 - 90]
					ENDWHILE
					IF [#107 >= 45]
						#107 = [-1 * [#107 - 90]]
					ENDIF
					;Berechnung des Werkstuecknullpunktes (eingeschlossener Punkt zwischen Gerade und Punkt)
					;Berechnung Ortsvektor X
					#112 = [#[4540 + [#101 * 2]]] ; X1
					#113 = [#[4542 + [#101 * 2 ]]] ; X2 
					#114 = [#[4541 + [#101 * 2 ]]] ; Y1
					#115 = [#[4543 + [#101 * 2 ]]] ; Y2
					msg "Berechnung mit den Punkten X1: "#112" Y1: "#114" X2: "#113" Y2: "#115
					;Berechnung von Nx
					#116 = [#114 - #115]
					;Berechnugn von Ny
					#117 = [#113 - #112]
					;Berechnung l
					#118 = SQRT[[#116 ** 2] + [#117 ** 2]]
					;Berechnung a,b
					#119 = [#116 / #118]
					#120 = [#117 / #118]
					;Berechnung c
					#121 = [-[[#119 * #112] + [#120 * #114]]]
					msg "Ergebnis: A: "#119" B: "#120" C: "#121" gegen den Punkt X1: "[#[4544 + [[#101] * 2 ]]]" Y1: "[#[4545 + [[#101] * 2]]]
					M502 A[#119]  B[#120] C[#121]  D[#[4544 + [[#101] * 2 ]]] E[#[4545 + [[#101] * 2]]]
					#109 = #3201 ;Werkstuecknullpunktes X
					#110 = #3202 ;Werkstuecknullpunktes Y
					msg "Berechnete Korrektur, X: "#109" Y: "#110", Rotation: "#107
					G69 ; Rotation deaktivieren
					G92.1 ; Zuruecksetzten der Achsen X,Y Werte
					msg "Angewendete Korrektur, X: "[-1*#109 + #5001]" Y: "Y[-1*#110 +#5002]", Rotation: "[-1*#107]
					G92 X[-1*#109 + #5001] Y[-1*#110 +#5002] ; Verschieben des Werkstuecknullpunktes in den Koordinatenursprung
					G68 X0 Y0 R[#107]; Rotation um den Koordinatenursprung
				ELSE
					msg "Es konnte kein Winkel zwischen den Punkten ermittelt werden"
				ENDIF 				
			ELSE
                Exec "\\dialogBasic\\dialogBasic.exe" "-b=Ja,Nein -r=1,0 -d=\"Es wurden nicht alle benoetigten Punkte eingegeben. Bitte ergaenzen Sie notwendige Punkte\"" 600000
			ENDIF
ENDIF
ENDIF
ENDIF
ENDSUB
;***************************************************************************************
Sub user_8 ; Antasten eines Innenkreises/einer Kreistasche und setzen des XY-Nullpunktes in die Mitte der Kreistasche
    #3080 = 0
	#3082 = 0; Index des ersten freien Punktepaars
	WHILE [#3080 <> 6]
		#[1+#3080] = #[4556 + #3080]
		#3080 = [#3080 +1]
	ENDWHILE
	
	#3080 = 0
	WHILE [#3080 <> 6]
		IF [[#[4556 + #3080] == -10000000000] AND [#[4556 + #3080 + 1] == -10000000000]]]
			#3082 = [4556 + #3080]
			#3080 = 6
		ELSE
				#3080 = [#3080 +2]
		ENDIF
	ENDWHILE
	
	
	msg "Moegliche Eingabe in Feld 7: 1-4 Punkt erfassen in X+ Y+ X- Y-, 5 Berechnung starten, 6 Punkte löschen"
	dlgmsg "Folgende Punkte wurde erfasst:" "P1X" 1 "P1Y" 2 "P2X" 3 "P2Y" 4 "P3X" 5 "P3Y" 6 "Input" 7
	IF [#5398 == 1]
		#3081 = #7
		IF [[#3081 > 0] AND [#3081 < 5]]
			;Punkt erfassen in +X -X +Y -Y
			IF [[#3081 == 1] OR [#3081 == 3]]
				; Verfahren in X-Richtung
				#3083 = 1
			ELSE 
				; Verfahren in Y-Richtung
				#3083 = 3
			ENDIF 
			IF [#3081 < 3]
				; positive Verfahrrichtung
				#3083 = [#3083 + 0]
			ELSE 
				; negative Verfahrrichtung
				#3083 = [#3083 + 1]
			ENDIF
			m503 A[#3083] B25
			#[#3082] = #3303
			#[#3082 + 1] = #3304
		ENDIF
		IF [#3081 == 5]
		; Berechnung starten
			m505 A[#4556] B[#4557] C[#4558] D[#4559] E[#4560] F[#4561]
			G92.1 ; Zuruecksetzten der Achsen X,Y Werte
			msg "Angewendete Korrektur, X: "[-1*#301 + #5001]" Y: "Y[-1*#302 +#5002]
			G92 X[-1*#301 + #5001] Y[-1*#302 +#5002] ; Verschieben des Werkstuecknullpunktes in den Koordinatenursprung
		ENDIF
		IF [#3081 == 6]
			; Punkte loeschen
			#3080 = 0
			WHILE [#3080 <> 6]
				#[4556 + #3080] = -10000000000
				#3080 = [#3080 +1]
			ENDWHILE
		ENDIF
	ENDIF
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
        G69
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
			#5100 = [#25 / #24]
			#5101 = ATAN[#5100]/[1]
            #5399 = [#5101 * [3.14159265359 / 180]]
    endif
	if [[#25] >= 0] THEN
        if [[#24] < 0] THEN
			#5100 = [#25 / #24]
			#5101 = ATAN[#5100]/[1]
            #5399 = [[[#5101 * [3.14159265359 / 180]] +  3.14159265359]
        endif
    endif
	if [[#25] < 0] THEN
        if [[#24] < 0] THEN
            #5100 = [#25 / #24]
			#5101 = ATAN[#5100]/[1]
            #5399 = [[[#5101] * [3.14159265359 / 180]] -  3.14159265359]
        endif
    endif
    if [#24 == 0] THEN
        if [#25 == 0] THEN
            msg "Parameter X and Y is zero, so m501 is undefined"
            #5399 = -10000000000
        endif
        if [[#25] > 0] THEN
            #5399 =  1.57079632679
        endif        
        if [[#25] < 0] THEN
            #5399 =  -1.57079632679
        endif
    endif
endsub

sub m500
; CalcAngleWithFourPoints
; A=AX B=AY C=BX D=BY E=CX F=CY G=DX H=DY
; Diese Funktion berechnet den Winkel zwischen zwei Geraden
msg "Call of m500 with A ="#1" and B = "#2" and C = "#3" and D = "#4" and E = "#5" and F = "#6"
msg "and G = "#7" and H = "#8
#3001 = #1
#3002 = #2
#3003 = #3
#3004 = #4
#3005 = #5
#3006 = #6
#3007 = #7
#3008 = #8
#3015 = 1 ; merker ob valide daten

#3009 = [#3006 - #3002]; CY - AY
#3010 = [#3005 - #3001]; CX - AX
IF [[#3009 == 0] AND [#3010 == 0]]
	#3015 = 0
ELSE
	m501 X#3010 Y#3009
	#3011 = #5399 ;Store value
	msg "Call of m501 (ext) with X ="#3010" and Y = "#3009", result: "#5399
ENDIF

#3012 = [#3008 - #3004]; DY - BY
#3013 = [#3007 - #3003]; DX - BX
msg "#3012:"#3012"#3013:"#3013
IF [[#3012 == 0] AND [#3013 == 0]]
	#3015 = 0
ELSE
	m501 X#3013 Y#3012
	msg "Call of m501 (ext) with X ="#3013" and Y = "#3012", result: "#5399
	#3014 = #5399 ;Store value
ENDIF

IF [#3015 == 1]
	#5399 = [#3014 - #3011]
	msg "m500 call with return: "#5399
ELSE
	#5399 = -10000000000
	msg "m500 call invalid"
ENDIF
endsub

sub m502
; CalcPoint of intersection between Point and line
; A=A0 B=B0 C=c D=PX E=PY
; a0 * x + b0 * y +c = 0
; P(PX, PY)
; Gibt Werte in #3201 und #3202 zurueck
msg "A0:"#1"B0:"#2"C:"#3"X:"#4"Y:"#5
#6 = [-1 * [#1 * #4 + #2 * #5 + #3]]
#7 = [#1 * #1 + #2 * #2]
#6 = [#6 / #7] ;-1 * (a * x1 + b * y1 + c) / (a * a + b * b)
#3201 = [#6 * #1 + #4]; #6 * a + x1
#3202 = [#6 * #2 + #5]; #6 * b + y1
msg "Return m502 X: "#3201" Y: "#3202
endsub

Sub m503 ; Anfahren eines Werkstuecks bis der Taster ausloest
; Parameter A=Anfahrrichtung (1=+X, 2=-X, 3=+Y, 4=-Y)
; Parameter B=Maximaler Anfahrweg
; Rueckgabe des X und Y Wertes ueber die Register 3303 und 3304
IF [[#1 > 4] OR [#1 < 1]]
    DlgMsg "Interner Fehler! Das Macro m503 wurde mit einer ungueltigen Anfahrrichtung ausgefuehrt
	#5399 = -1 ; Return value 
ELSE
IF [[#2 > 25] OR [#2 < 0]]
    DlgMsg "Interner Fehler! Das Macro m503 wurde mit einem ungueltigen Anfahrweg ausgefuehrt
	#5399 = -1 ; Return value 
ELSE
    ;Hier kommt die eigentliche Funktion
msg "Bitte fahren Sie den 3D-Taster in die Naehe des anzutastenen Punktes. Der maximale Abstand darf:"#2" mm betragen und bestaetigen dann mit der Tastenkombination STRG + G"
m0
#3301 = #1
#3302 = #2
    IF [#1 MOD 2 == 0] ; Pruefen ob eine negative Bewegung vorliegt
        #2 = -#2
ENDIF
    IF [[#1 == 1] OR [#1 == 2]] ; Antastung mit Bewegung entlang der X-Achse
G91 G38.2 x[#2] F50
    IF [#5067 == 1]                    ; Wenn Sensor gefunden wurde
        #3 = [-#2 / 2]
        G91 G38.2 x#3 F20
        IF [#5067 == 1]                ; Wenn Sensor gefunden wurde
			IF [#1 == 1]
				#3303 = [#5051 + 1]
			ELSE
				#3303 = [#5051 - 1]
			ENDIF
            #3304 = #5052
			#5399 = 1 ; Return value 
        ENDIF
    ELSE
        DlgMsg "FEHLER: 3D-Taster wurde nicht ausgeloest. Wiederholen?"
        IF [#5398 == 1] ;OK
        m503 A[#3301] B[#3302]
    ENDIF
    ENDIF 
        ELSE ; Antastung mit Bewegung entlang der Y-Achse
G91 G38.2 y[#2] F50
    IF [#5067 == 1]                    ; Wenn Sensor gefunden wurde
        #3 = [-#2 / 2]
        G91 G38.2 y#3 F20
        IF [#5067 == 1]                ; Wenn Sensor gefunden wurde
            #3303 = #5051
			IF [#1 == 3]
				#3304 = [#5052 + 1]
			ELSE
				#3304 = [#5052 - 1]
			ENDIF
			#5399 = 1 ; Return value 
        ENDIF

    ELSE
        DlgMsg "FEHLER: 3D-Taster wurde nicht ausgeloest. Wiederholen?"
        IF [#5398 == 1] ;OK
			m503 A[#3301] B[#3302]
		ENDIF
		#5399 = -1 ; Return value 
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
		#5399 = -1 ; Return value 
	ELSE
        G91 G38.2 Z-#1 F100                ; fahre maximal #1 mm nach unten bis der Taster ausloest
    IF [#5067 == 1]                    ; Taster ausgeloest
        G91 G38.2 Z#1 F20                ; Taster freifahren
        IF [#5067 == 1]                ; Taster ausgeloest
			G49 ; Deaktivieren der Toolkompensation
            G92 Z#2                ; Z-Koordinate auf #2 setzen
            G91 G1 F100 Z10            ; bissl wegfahren vom Beruehrpunkt
			G43 H0; Aktivieren der Kompensation
            msg "Z tasten erfolgreich, auf Z="#2" mm gesetzt"
			#5399 = 1 ; Return value 
		ENDIF
    ELSE
        errmsg "Taster konnte nicht ausloesen - Entfernung zum Werkstueck ueberschritten?"
		#5399 = -1 ; Return value 
	ENDIF
    ENDIF
    G90 ; absolute Koordinaten wieder aktivieren
ENDSUB

sub m505; Berechnung eines Kreises aus drei Punkten
; Benutzt die Koordinaten der Parameter A=x1 B=y1 C=x2 D=y2 E=x3 F=y3
; Gibt ueber Parameter #300 den Radius des Kreises zurueck
; #301 = X Koordinate Mittelpunkt
; #302 = Y Koordinate Mittelpunkt
msg "Parameter A: "#1" B: "#2" C: "#3" D: "#4" E: "#5" F: "#6
#3500 = [#1 - #3] ;x12 = x1 - x2
#3501 = [#1 - #5] ;x13 = x1 - x3 

#3502 = [#2 - #4] ;y12 = y1 - y2
#3503 = [#2 - #6] ;y13 = y1 - y3 

#3504 = [#6 - #2] ;y31 = y3 - y1
#3505 = [#4 - #2] ;y21 = y2 - y1

#3506 = [#5 - #1] ;x31 = x3 - x1
#3507 = [#3 - #1] ;x21 = x2 - x1

msg "Berechnet Werte: x12: "#3500" x13: "#3501" y12: "#3502" y13: "#3503
msg "Berechnet Werte: y31: "#3504" y21: "#3505" x31: "#3506" x21: "#3507

#3508 = [[#1 ** 2] - [#5 ** 2]] ;sx13 x1^2 - x3^2 
#3509 = [[#2 ** 2] - [#6 ** 2]] ;sy13 y1^2 - y3^2 

#3510 = [[#3 ** 2] - [#1 ** 2]] ;sx21 pow(x2, 2) - pow(x1, 2);
#3511 = [[#4 ** 2] - [#2 ** 2]] ;sy21 pow(y2, 2) - pow(y1, 2); 

msg "Berechnet Werte: sx13: "#3508" sy13: "#3509" sx21: "#3510" sy21: "#3511

#3512 = [[[#3508 * #3500]+[#3509 * #3500]+[#3510*#3501]+[#3511*#3501]]/[2*[[#3504 * #3500]-[#3505*#3501]]]] ;int f = ((sx13) * (x12) + (sy13) * (x12) + (sx21) * (x13) + (sy21) * (x13)) / (2 * ((y31) * (x12) - (y21) * (x13))); 
#3513 = [[[#3508 * #3502]+[#3509 * #3502]+[#3510*#3503]+[#3511*#3503]]/[2*[[#3506 * #3502]-[#3507*#3503]]]] ;int g = ((sx13) * (y12) + (sy13) * (y12) + (sx21) * (y13) + (sy21) * (y13)) / (2 * ((x31) * (y12) - (x21) * (y13))); 

#3514 = [[-1 * [#1 ** 2]] - [#2 ** 2] - [2 * #3513 * #1] - [2 * #3512 * #2]] ;c = -pow(x1, 2) - pow(y1, 2) - 2 * g * x1 - 2 * f * y1

msg "Berechnet Werte: f: "#3512" g: "#3513" c: "#3514
;eqn of circle be x^2 + y^2 + 2*g*x + 2*f*y + c = 0 
;where centre is (h = -g, k = -f) and radius r 
;as r^2 = h^2 + k^2 - c 
#3515 = [#3513 * -1] ;h = -g
#3516 = [#3512 * -1] ;k = -f
#3517 = [[#3515 * #3515] + [#3516 * #3516] - #3514]  ;sqr_of_r = h * h + k * k - c

#3518 = SQRT[#3517] ;float r = sqrt(sqr_of_r);
#300 = #3518
#301 = #3515
#302 = #3516
msg "Berechneter Kreis mit Radius r: "#300" und Mittelpunkt ("#301"/"#302")"
endsub


