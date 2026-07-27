// ============================================================
// AutoPlant236.lsl
// OPENSIM WALDPFLANZER SKRIPT MIT DIALOG-MENÜ
// ============================================================

// ===== GLOBALE VARIABLEN =====
integer gIntX;
integer gIntY;  
integer gIntZ;

integer gIntStartX;
integer gIntStartY;
integer gIntEndX;
integer gIntEndY;

float gFltPlantProbability;
float gFltRandMax;

float FLATTEN_HEIGHT = 21.0; // Standard-Höhe zum Einebnen
float ROUGHNESS_AMOUNT = 0.15;   // 0.0 = keine Änderung, 1.0 = maximale Änderung
float MAX_HEIGHT_CHANGE = 2.0;  // Maximale Höhenänderung in Metern
float NOISE_SCALE = 10.0;       // Skalierung für Perlin-Noise
float NOISE_AMPLITUDE = 3.0;    // Amplitude für Perlin-Noise
float BASE_HEIGHT = 20.0;       // Basis-Höhe für die Region

// ===== START/STOP-FUNKTION =====
integer gIntRunning = FALSE;
key gKeyToucher;
integer gIntCurrentX;
integer gIntCurrentY;

float Pflanszeit = 0.5; // Geschwindigkeit der Pflanzenbildung

// ===== PFLANZPARAMETER =====
integer PFLANZABSTAND = 6;

// ===== KOMBINIERTE LISTE FÜR ALLE OBJEKTE =====
// Format: [Name, Höhe, Priorität, X-Rotation, Y-Rotation, Z-Rotation, Z-Offset]
// Prioritäten basierend auf deutschen Waldanteilen:
// Kiefer: 22%, Fichte: 21%, Rotbuche: 17%, Eiche: 12%, Birke: 4.7%, Ahorn: 3.0%, Lärche: 2.9%, Esche: 1.8%
list ALLE_OBJEKTE = [
    // Bäume mit deutschen Waldanteilen
    "European-Beech-tree-A", 10.0, 17, 0.0, 0.0, 0.0, 0.0,
    "European-Beech-tree-B", 10.0, 17, 0.0, 0.0, 0.0, 0.0,
    "European-Oak-tree", 12.0, 12, 0.0, 0.0, 0.0, 0.0,
    "European-Larch-tree", 15.0, 3, 90.0, 0.0, 0.0, 0.0,
    "European-Pine-tree", 12.0, 22, 0.0, 0.0, 0.0, 0.0,
    "European-Spruce-tree", 15.0, 21, 0.0, 0.0, 0.0, 0.0,
    "European-Birch-tree", 10.0, 5, 90.0, 0.0, 0.0, 0.0,
    "European-Maple-tree", 12.0, 3, 0.0, 0.0, 0.0, 0.0,
    "European-Ash-tree", 13.0, 2, 0.0, 0.0, 0.0, 0.0,
    
    // Büsche (Priorität 8)
    "Buesche-1", 3.0, 8, 90.0, 0.0, 0.0, -2.00,
    "Buesche-2", 3.0, 8, 90.0, 0.0, 0.0, -2.00,
    "Buesche-3", 3.0, 8, 90.0, 0.0, 0.0, -2.00,
    "Buesche-4", 3.0, 8, 90.0, 0.0, 0.0, -2.00,
    
    // Farne (Priorität 6)
    "Fern-1", 1.2, 6, 90.0, 0.0, 0.0, -0.70,
    "Fern-2", 1.2, 6, 90.0, 0.0, 0.0, -0.70,
    "Fern-3", 1.2, 6, 90.0, 0.0, 0.0, -0.70,
    "Fern-4", 1.2, 6, 90.0, 0.0, 0.0, -0.70,
    
    // Todholz (Priorität 4)
    "Todholz-1", 1.5, 4, 0.0, 0.0, 0.0, -1.30,
    "Todholz-2", 1.5, 4, 0.0, 0.0, 0.0, -1.30,
    "Todholz-3", 1.5, 4, 0.0, 0.0, 0.0, -1.30,
    "Todholz-4", 1.5, 4, 0.0, 0.0, 0.0, -1.30,
    
    // Gräser (Priorität 5)
    "Grass-1", 0.5, 5, 0.0, 0.0, 0.0, -0.10,
    "Grass-2", 0.5, 5, 0.0, 0.0, 0.0, -0.10,
    "Grass-3", 0.5, 5, 180.0, 0.0, 0.0, 0.70,
    "Grass-4", 0.5, 5, 0.0, 0.0, 0.0, -0.10,
    
    // Steine (Priorität 3)
    "Stone-1", 0.8, 3, 0.0, 0.0, 0.0, -0.40,
    "Stone-2", 0.8, 3, 0.0, 0.0, 0.0, -3.00,
    "Stone-3", 0.8, 3, 0.0, 0.0, 0.0, -0.40,
    "Stone-4", 0.8, 3, 0.0, 0.0, 0.0, -0.40
];

// ===== TERRAIN-TEXTUREN =====
float TextureLow = 10.0;
float TextureHigh = 30.0;

key Terrain_Dirt = "1e78c37b-90a1-40d3-a913-31c965309679";
key Terrain_Grass = "a9b4d0d5-5679-4fd5-b9e3-ac4367ea9b95";
key Terrain_Mountain = "795204d3-bd28-467c-b526-08b95090841e";
key Terrain_Rock = "4b012b05-a357-46af-8e6e-e8a9aa501a8c";

// ===== DIALOG-MENÜ VARIABLEN =====
integer MENU_CHANNEL;
integer listenHandle;
string MENU_TEXT = "\n🌳 Wähle eine Aktion:";
list MENU_BUTTONS = ["🔄 Aufrauhen", "🏔️ Einebnen","❌ Schließen",  "🌳 Pflanzen", "🟫 Terrain"];

// ===== HILFSFUNKTIONEN =====
float getObjectHeight(string objectName)
{
    integer index = llListFindList(ALLE_OBJEKTE, [objectName]);
    if (index != -1)
        return llList2Float(ALLE_OBJEKTE, index + 1);
    return 4.0;
}

float getObjectRotationX(string objectName)
{
    integer index = llListFindList(ALLE_OBJEKTE, [objectName]);
    if (index != -1)
        return llList2Float(ALLE_OBJEKTE, index + 3);
    return 0.0;
}

float getObjectRotationY(string objectName)
{
    integer index = llListFindList(ALLE_OBJEKTE, [objectName]);
    if (index != -1)
        return llList2Float(ALLE_OBJEKTE, index + 4);
    return 0.0;
}

float getObjectRotationZ(string objectName)
{
    integer index = llListFindList(ALLE_OBJEKTE, [objectName]);
    if (index != -1)
        return llList2Float(ALLE_OBJEKTE, index + 5);
    return 0.0;
}

float getObjectZOffset(string objectName)
{
    integer index = llListFindList(ALLE_OBJEKTE, [objectName]);
    if (index != -1)
        return llList2Float(ALLE_OBJEKTE, index + 6);
    return 0.0;
}

rotation getRotation(float gradX, float gradY, float gradZ)
{
    return llEuler2Rot(<gradX * DEG_TO_RAD, gradY * DEG_TO_RAD, gradZ * DEG_TO_RAD>);
}

// ===== BERECHTIGUNGSPRÜFUNG =====
integer checkLandPermissions(key avatar)
{
    // 1. Prüfen, ob der Nutzer der Besitzer des Landes ist
    key parcelID = osGetParcelID();
    list parcelDetails = osGetParcelDetails(parcelID, [PARCEL_DETAILS_OWNER]);
    key parcelOwner = llList2Key(parcelDetails, 0);
    
    if (parcelOwner == avatar)
    {
        return TRUE;
    }
    
    // 2. Prüfen, ob der Nutzer in der Gruppenliste des Grundstücks ist
    parcelDetails = osGetParcelDetails(parcelID, [PARCEL_DETAILS_GROUP]);
    key parcelGroup = llList2Key(parcelDetails, 0);
    
    if (parcelGroup != NULL_KEY)
    {
        if (llSameGroup(avatar))
        {
            return TRUE;
        }
    }
    
    // 3. Prüfen, ob der Nutzer allgemeine Baurechte hat
    integer parcelFlags = llGetParcelFlags(llGetPos());
    if (parcelFlags & PARCEL_FLAG_ALLOW_CREATE_OBJECTS)
    {
        return TRUE;
    }
    
    return FALSE;
}

// ===== TERRAIN-FUNKTIONEN =====
setTerrain()
{
    if (!checkLandPermissions(llGetOwner()))
    {
        llOwnerSay("❌ Keine Berechtigung für Terrain-Änderungen!");
        return;
    }
    
    list textures = [Terrain_Dirt, Terrain_Grass, Terrain_Mountain, Terrain_Rock];
    integer types = 2;
    osSetTerrainTextures(textures, types);
    
    osSetTerrainTexture(0, Terrain_Dirt);
    osSetTerrainTextureHeight(0, TextureLow, TextureHigh);
    osSetTerrainTexture(1, Terrain_Grass);
    osSetTerrainTextureHeight(1, TextureLow, TextureHigh);
    osSetTerrainTexture(2, Terrain_Mountain);
    osSetTerrainTextureHeight(2, TextureLow, TextureHigh);
    osSetTerrainTexture(3, Terrain_Rock);
    osSetTerrainTextureHeight(3, TextureLow, TextureHigh);
    
    llModifyLand(LAND_NOISE, 0);
    osTerrainFlush();
    
    llOwnerSay("✅ Terrain-Texturen wurden gesetzt und aufgeraut!");
}

// ===== FUNKTION ZUM EINEBNEN DER REGION =====
flattenRegion(float targetHeight)
{
    // Prüfen ob der Aufrufer Berechtigungen hat
    if (!checkLandPermissions(llGetOwner()))
    {
        llOwnerSay("❌ Keine Berechtigung zum Einebnen der Region!");
        return;
    }
    
    llOwnerSay("🏔️ Region wird auf " + (string)targetHeight + " Meter eingeebnet...");
    
    // Region-Größe ermitteln
    vector regionSize = osGetRegionSize();
    integer regionX = (integer)regionSize.x;
    integer regionY = (integer)regionSize.y;
    
    // In Blöcken arbeiten um Heap-Overflow zu vermeiden
    integer blockSize = 10;
    integer x;
    integer y;
    
    for (x = 0; x < regionX; x += blockSize)
    {
        for (y = 0; y < regionY; y += blockSize)
        {
            integer endX = x + blockSize;
            integer endY = y + blockSize;
            if (endX > regionX) endX = regionX;
            if (endY > regionY) endY = regionY;
            
            integer ix;
            integer iy;
            for (ix = x; ix < endX; ix++)
            {
                for (iy = y; iy < endY; iy++)
                {
                    osSetTerrainHeight(ix, iy, targetHeight);
                }
            }
            llSleep(0.01);
        }
    }
    
    // Änderungen ans Terrain übergeben
    osTerrainFlush();
    
    llOwnerSay("✅ Region wurde auf " + (string)targetHeight + " Meter eingeebnet!");
}

// ===== FUNKTION ZUM AUFRAUHEN DER REGION (OPTIMIERT) =====
roughenRegion(float roughnessAmount, float maxHeightChange)
{
    if (!checkLandPermissions(llGetOwner()))
    {
        llOwnerSay("❌ Keine Berechtigung zum Aufrauhen der Region!");
        return;
    }
    
    llOwnerSay("🏔️ Region wird aufgeraut (Stärke: " + (string)(roughnessAmount * 100) + "%, max. Höhenänderung: " + (string)maxHeightChange + "m)...");
    
    // Region-Größe ermitteln
    vector regionSize = osGetRegionSize();
    integer regionX = (integer)regionSize.x;
    integer regionY = (integer)regionSize.y;
    
    // In Blöcken arbeiten um Heap-Overflow zu vermeiden
    integer blockSize = 10;
    integer x;
    integer y;
    
    for (x = 0; x < regionX; x += blockSize)
    {
        for (y = 0; y < regionY; y += blockSize)
        {
            // Nur innerhalb der Region bleiben
            integer endX = x + blockSize;
            integer endY = y + blockSize;
            if (endX > regionX) endX = regionX;
            if (endY > regionY) endY = regionY;
            
            // Block verarbeiten
            integer ix;
            integer iy;
            for (ix = x; ix < endX; ix++)
            {
                for (iy = y; iy < endY; iy++)
                {
                    float currentHeight = osGetTerrainHeight(ix, iy);
                    
                    // Zufällige Höhenänderung
                    float heightChange = (llFrand(1.0) * 2.0 - 1.0) * maxHeightChange * roughnessAmount;
                    float newHeight = currentHeight + heightChange;
                    
                    // Begrenzen auf sinnvolle Werte
                    if (newHeight < 0.0) newHeight = 0.0;
                    if (newHeight > 100.0) newHeight = 100.0;
                    
                    osSetTerrainHeight(ix, iy, newHeight);
                }
            }
            
            // Nach jedem Block kurz pausieren für Heap-Management
            llSleep(0.01);
        }
    }
    
    // Änderungen ans Terrain übergeben
    osTerrainFlush();
    
    llOwnerSay("✅ Region wurde erfolgreich aufgeraut!");
}

// ===== PFLANZEN-FUNKTIONEN =====
plantOneTree()
{
    if (!gIntRunning) return;
    
    if (gIntCurrentX >= gIntEndX || gIntCurrentY >= gIntEndY)
    {
        gIntRunning = FALSE;
        llOwnerSay("✅ Pflanzvorgang abgeschlossen!");
        llSetText("Fertig - Klicke für neues Menü", <0,1,0>, 1.0);
        llSetTimerEvent(0.0);
        return;
    }
    
    gIntX = gIntCurrentX;
    gIntY = gIntCurrentY;
    
    llSetRegionPos(<gIntX, gIntY, gIntZ>);
    llSetText("X: " + (string)gIntX + " Y: " + (string)gIntY, <1,1,1>, 1.0);
    
    // Zufällig entscheiden, ob überhaupt etwas gepflanzt wird
    float fltDoIRez = llFrand(1.0);
    if (fltDoIRez >= gFltPlantProbability) 
    {
        gIntCurrentY += PFLANZABSTAND;
        if (gIntCurrentY >= gIntEndY)
        {
            gIntCurrentY = gIntStartY + (PFLANZABSTAND / 2);
            gIntCurrentX += PFLANZABSTAND;
        }
        return;
    }
    
    // ===== GEWICHTETE AUSWAHL =====
    list verfuegbareObjekte = [];
    integer listLength = llGetListLength(ALLE_OBJEKTE) / 7;
    integer i;
    
    for (i = 0; i < listLength; i++)
    {
        string objName = llList2String(ALLE_OBJEKTE, i * 7);
        if (llGetInventoryType(objName) == INVENTORY_OBJECT)
        {
            float objHeight = llList2Float(ALLE_OBJEKTE, (i * 7) + 1);
            integer objPriority = llList2Integer(ALLE_OBJEKTE, (i * 7) + 2);
            float objRotationX = llList2Float(ALLE_OBJEKTE, (i * 7) + 3);
            float objRotationY = llList2Float(ALLE_OBJEKTE, (i * 7) + 4);
            float objRotationZ = llList2Float(ALLE_OBJEKTE, (i * 7) + 5);
            float objZOffset = llList2Float(ALLE_OBJEKTE, (i * 7) + 6);
            verfuegbareObjekte += [objName, objHeight, objPriority, objRotationX, objRotationY, objRotationZ, objZOffset];
        }
    }
    
    if (llGetListLength(verfuegbareObjekte) == 0)
    {
        llOwnerSay("⚠️ Keine Objekte im Inventar gefunden!");
        gIntRunning = FALSE;
        llSetTimerEvent(0.0);
        return;
    }
    
    // Gesamtgewicht berechnen
    integer availableCount = llGetListLength(verfuegbareObjekte) / 7;
    integer totalWeight = 0;
    for (i = 0; i < availableCount; i++)
    {
        totalWeight += llList2Integer(verfuegbareObjekte, (i * 7) + 2);
    }
    
    // Zufällige Auswahl basierend auf Gewicht
    integer randomWeight = (integer)llFrand(totalWeight);
    integer selectedIndex = 0;
    integer cumulativeWeight = 0;
    
    for (i = 0; i < availableCount; i++)
    {
        integer priority = llList2Integer(verfuegbareObjekte, (i * 7) + 2);
        cumulativeWeight += priority;
        if (randomWeight < cumulativeWeight)
        {
            selectedIndex = i;
            i = availableCount;
        }
    }
    
    // Objekt auswählen
    string gStrObjectName = llList2String(verfuegbareObjekte, selectedIndex * 7);
    float objectHeight = llList2Float(verfuegbareObjekte, (selectedIndex * 7) + 1);
    float rotationX = llList2Float(verfuegbareObjekte, (selectedIndex * 7) + 3);
    float rotationY = llList2Float(verfuegbareObjekte, (selectedIndex * 7) + 4);
    float rotationZ = llList2Float(verfuegbareObjekte, (selectedIndex * 7) + 5);
    float zOffset = llList2Float(verfuegbareObjekte, (selectedIndex * 7) + 6);
    
    // Position setzen
    vector vecNowPos = llGetPos();
    float fltLandHeight = osGetTerrainHeight((integer)vecNowPos.x, (integer)vecNowPos.y);
    
    integer intNewX = (integer)vecNowPos.x;
    integer intNewY = (integer)vecNowPos.y;
    integer intNewZ = (integer)fltLandHeight;
    
    vecNowPos = <intNewX, intNewY, intNewZ>;
    llSetRegionPos(vecNowPos);
    
    // ===== ROTATION =====
    // Basis-Rotation aus der Liste (X und Y fest, Z wird durch zufälligen Wert ersetzt)
    rotation baseRotation = getRotation(rotationX, rotationY, 0.0);
    
    // Zufällige Z-Rotation für natürlichen Wald (0-360 Grad)
    float randomZRotation = llFrand(360.0);
    rotation randomRotation = llEuler2Rot(<0.0, 0.0, randomZRotation * DEG_TO_RAD>);
    
    // Beide Rotationen kombinieren
    rotation finalRotation = baseRotation * randomRotation;
    
    // Objekt rezzen mit kombinierter Rotation
    llRezObject(gStrObjectName, 
                llGetPos() + <0.0, 0.0, objectHeight + zOffset>,
                <0.0, 0.0, 0.0>,
                finalRotation,
                0);
    llModifyLand(LAND_NOISE, 0);
    llSleep(0.1);
    
    // Debug-Ausgabe (optional)
    // llOwnerSay("🌱 " + gStrObjectName + " | X-Rot: " + (string)rotationX + "° | Y-Rot: " + (string)rotationY + "° | Z-Rot: " + (string)(randomZRotation) + "° | Z-Off: " + (string)zOffset);
    
    // Zur nächsten Position
    gIntCurrentY += PFLANZABSTAND;
    if (gIntCurrentY >= gIntEndY)
    {
        gIntCurrentY = gIntStartY + (PFLANZABSTAND / 2);
        gIntCurrentX += PFLANZABSTAND;
    }
}

startPlanting(key toucher)
{
    if (!checkLandPermissions(toucher))
    {
        llOwnerSay("❌ Du hast nicht die erforderlichen Landrechte zum Pflanzen!");
        llOwnerSay("Benötigte Berechtigungen (mindestens eine):");
        llOwnerSay("  • Grundstücksbesitzer");
        llOwnerSay("  • Mitglied der Grundstücksgruppe");
        llOwnerSay("  • Baurechte auf dem Grundstück");
        return;
    }
    
    vector regionSize = osGetRegionSize();
    gIntStartX = 0;
    gIntStartY = 0;
    gIntEndX = (integer)regionSize.x;
    gIntEndY = (integer)regionSize.y;
    
    gFltPlantProbability = 0.7;
    gIntZ = 0;
    
    gIntRunning = TRUE;
    gIntCurrentX = gIntStartX + (PFLANZABSTAND / 2);
    gIntCurrentY = gIntStartY + (PFLANZABSTAND / 2);
    
    // Anzahl der verfügbaren Objekte zählen
    integer availableCount = 0;
    integer listLength = llGetListLength(ALLE_OBJEKTE) / 7;
    integer i;
    for (i = 0; i < listLength; i++)
    {
        string objName = llList2String(ALLE_OBJEKTE, i * 7);
        if (llGetInventoryType(objName) == INVENTORY_OBJECT)
            availableCount++;
    }
    
    llOwnerSay("🌳 Starte Pflanzvorgang mit " + (string)availableCount + " verfügbaren Objekten...");
    llOwnerSay("🌳 Waldzusammensetzung (deutscher Wald):");
    llOwnerSay("  • Kiefer: 22%, Fichte: 21%, Rotbuche: 17%");
    llOwnerSay("  • Eiche: 12%, Birke: 4.7%, Ahorn: 3.0%");
    llOwnerSay("  • Lärche: 2.9%, Esche: 1.8%");
    llOwnerSay("🌳 Berechtigung für " + llKey2Name(toucher) + " verifiziert.");
    llSetText("🌳 Pflanze... Klicke zum Stoppen", <1,1,0>, 1.0);

    
    llSetTimerEvent(Pflanszeit);
}

// ===== HAUPTTEIL DES SKRIPTS =====
default
{
    state_entry()
    {
        MENU_CHANNEL = -1 - (integer)("0x" + llGetSubString((string)llGetKey(), -7, -1));
        llOwnerSay("🌳 Waldpflanzer bereit. Klicke für Menü.");
        llSetText("Bereit - Klicke für Menü", <0,1,0>, 1.0);
        llSetTimerEvent(0.0);
    }
    
    touch_start(integer num_detected)
    {
        if (gIntRunning)
        {
            gIntRunning = FALSE;
            llSetTimerEvent(0.0);
            llListenRemove(listenHandle);
            llOwnerSay("⏹️ Pflanzvorgang wurde gestoppt!");
            llSetText("Gestoppt - Klicke für neues Menü", <1,0,0>, 1.0);
            return;
        }
        
        key toucher = llDetectedKey(0);
        gKeyToucher = toucher;
        
        if (!checkLandPermissions(toucher))
        {
            string avatarName = llKey2Name(toucher);
            llOwnerSay("❌ " + avatarName + " hat nicht die erforderlichen Landrechte!");
            llOwnerSay("Benötigte Berechtigungen (mindestens eine):");
            llOwnerSay("  • Grundstücksbesitzer");
            llOwnerSay("  • Mitglied der Grundstücksgruppe");
            llOwnerSay("  • Baurechte auf dem Grundstück");
            return;
        }
        
        llListenRemove(listenHandle);
        listenHandle = llListen(MENU_CHANNEL, "", toucher, "");
        llDialog(toucher, MENU_TEXT, MENU_BUTTONS, MENU_CHANNEL);
        llSetTimerEvent(60.0);
    }
    
    listen(integer channel, string name, key id, string message)
    {
        llSetTimerEvent(0.0);
        llListenRemove(listenHandle);
        
        if (message == "🌳 Pflanzen")
        {
            if (!checkLandPermissions(id))
            {
                llOwnerSay("❌ Du hast nicht die erforderlichen Landrechte zum Pflanzen!");
                return;
            }
            llOwnerSay("🌳 Starte Pflanzvorgang...");
            startPlanting(id);
        }
        else if (message == "🟫 Terrain")
        {
            if (!checkLandPermissions(id))
            {
                llOwnerSay("❌ Du hast nicht die erforderlichen Landrechte für Terrain-Änderungen!");
                return;
            }
            setTerrain();
            llDialog(id, "✅ Terrain-Texturen wurden aktualisiert.", ["OK"], MENU_CHANNEL);
        }
        else if (message == "🏔️ Einebnen")
        {
            if (!checkLandPermissions(id))
            {
                llOwnerSay("❌ Du hast nicht die erforderlichen Landrechte zum Einebnen!");
                return;
            }
            flattenRegion(FLATTEN_HEIGHT);
            llDialog(id, "✅ Region wurde auf " + (string)FLATTEN_HEIGHT + " Meter eingeebnet.", ["OK"], MENU_CHANNEL);
        }
        else if (message == "🔄 Aufrauhen")
        {
            if (!checkLandPermissions(id))
            {
                llOwnerSay("❌ Du hast nicht die erforderlichen Landrechte zum Aufrauhen!");
                return;
            }
            
            // Einfache Variante
            roughenRegion(ROUGHNESS_AMOUNT, MAX_HEIGHT_CHANGE);
            
            llDialog(id, "✅ Region wurde aufgeraut.", ["OK"], MENU_CHANNEL);
        }
        else if (message == "❌ Schließen")
        {
            llOwnerSay("Menü geschlossen.");
        }
        else if (message == "OK")
        {
            llOwnerSay("✅ OK.");
        }
    }
    
    timer()
    {
        if (gIntRunning)
        {
            plantOneTree();
        }
        else
        {
            llSetTimerEvent(0.0);
        }
    }
}