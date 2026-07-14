# OpenSim Procedural World

Durch die Nutzung eines INonSharedRegionModule klinkt sich das Addon direkt in den Lebenszyklus jeder einzelnen Region ein. [1, 2] 
Da OpenSimulator intern auf einem Heightmap-System für das Terrain basiert (welches der Viewer dann als 3D-Mesh rendert), 
manipuliert ein solches Modul den ITerrainChannel der Szene, 
weist der Region über Textur-UUIDs die 4 Oberflächenmaterialien zu und injiziert anschließend echte 3D-Mesh-Objekte (SceneObjectGroup) 
direkt via C#-Code in die mathematische Welt, anstatt den Umweg über Ingame-LSL-Skripte zu gehen.
Hier ist die vollständige, strukturierte Architektur und der C#-Code für ein solches vollautomatisches prozedurales OpenSim-Addon. [1] 

<img src="https://raw.githubusercontent.com/ManfredAabye/OpenSim-Procedural-World/refs/heads/main/OpenSimForest.jpg" alt="Project Badge" width="450">

---

## Vorbereitung: UUIDs im Code hinterlegen
Da OpenSimulator UUIDs zur Identifikation von Assets nutzt, müssen Sie im Modul die UUIDs Ihrer hochgeladenen 3D-Meshes und Texturen definieren:

* 4x Terrain-Texturen: Die UUIDs für Sand, Gras, Fels, Erde.
* 4x Bäume, 4x Gräser, 4x Büsche: Die UUIDs der fertig hochgeladenen .dae/glTF-Objekte (als Objekte bereits im Inventar oder direkt als Asset-ID in Ihrer Grid-Datenbank).

---

## Der C# Quellcode für das Region-Modul (ProceduralWorldModule.cs)
Erstellen Sie eine neue Klasse in Ihrem Addon-Verzeichnis (z.B. addon-modules/ProceduralWorld/ProceduralWorldModule.cs).

```c#
using System;using System.Collections.Generic;using log4net;using Nini.Config;using OpenMetaverse;using OpenSim.Framework;using OpenSim.Region.Framework.Interfaces;using OpenSim.Region.Framework.Scenes;using System.Reflection;
namespace OpenSim.Modules.ProceduralWorld
{
    // Implementiert INonSharedRegionModule – analog zur OpenSimBirds-Struktur
    public class ProceduralWorldModule : INonSharedRegionModule
    {
        private static readonly ILog m_log = LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
        private Scene m_scene;
        private bool m_enabled = true;
        private Random m_rnd = new Random();

        // --- KONFIGURATION (Vom Anwender definierte Parameter) ---
        private int m_treeCount = 150;
        private int m_grassCount = 400;
        private int m_bushCount = 100;
        private float m_maxVegetationHeight = 8.0f; // Maximale Skalierungsgröße

        // --- ASSET-UUIDS (Müssen durch Ihre echten Mesh-/Textur-UUIDs ersetzt werden) ---
        private readonly UUID[] TerrainMaterials = new UUID[4] {
            new UUID("00000000-0000-0000-0000-000000000001"), // Material 1 (z.B. Gras Niedrig)
            new UUID("00000000-0000-0000-0000-000000000002"), // Material 2 (z.B. Sand/Strand)
            new UUID("00000000-0000-0000-0000-000000000003"), // Material 3 (z.B. Fels/Steil)
            new UUID("00000000-0000-0000-0000-000000000004")  // Material 4 (z.B. Erde/Bergkuppe)
        };

        private readonly UUID[] TreeMeshUUIDs = new UUID[4] {
            new UUID("a1111111-0000-0000-0000-000000000000"), // Eiche Mesh
            new UUID("a2222222-0000-0000-0000-000000000000"), // Kiefer Mesh
            new UUID("a3333333-0000-0000-0000-000000000000"), // Birke Mesh
            new UUID("a4444444-0000-0000-0000-000000000000")  // Palme Mesh
        };

        private readonly UUID[] GrassMeshUUIDs = new UUID[4] {
            new UUID("b1111111-0000-0000-0000-000000000000"), // Feldgras
            new UUID("b2222222-0000-0000-0000-000000000000"), // Farngras
            new UUID("b3333333-0000-0000-0000-000000000000"), // Trockenes Gras
            new UUID("b4444444-0000-0000-0000-000000000000")  // Wildblumen-Gras
        };

        private readonly UUID[] BushMeshUUIDs = new UUID[4] {
            new UUID("c1111111-0000-0000-0000-000000000000"), // Beerenbusch
            new UUID("c2222222-0000-0000-0000-000000000000"), // Dichter Busch
            new UUID("c3333333-0000-0000-0000-000000000000"), // Heckenbusch
            new UUID("c4444444-0000-0000-0000-000000000000")  // Toter Busch
        };

        #region INonSharedRegionModule Members

        public void Initialise(IConfigSource source)
        {
            IConfig config = source.Configs["ProceduralWorld"];
            if (config != null)
            {
                m_enabled = config.GetBoolean("Enabled", true);
                m_treeCount = config.GetInt("TreeCount", m_treeCount);
                m_grassCount = config.GetInt("GrassCount", m_grassCount);
                m_bushCount = config.GetInt("BushCount", m_bushCount);
                m_maxVegetationHeight = config.GetFloat("MaxHeight", m_maxVegetationHeight);
            }
        }

        public void AddRegion(Scene scene)
        {
            if (!m_enabled) return;
            m_scene = scene;
        }

        public void RegionLoaded(Scene scene)
        {
            if (!m_enabled) return;

            m_log.Info($"[PROC_WORLD] Starte vollautomatische Generierung für Region: {scene.RegionInfo.RegionName}");
            
            // 1. Terrain modulieren & aufrauen
            GenerateTerrain(scene);

            // 2. Terrain-Texturen (4 Materialien) binden
            ApplyTerrainMaterials(scene);

            // 3. Vegetation prozedural platzieren
            PopulateVegetation(scene, TreeMeshUUIDs, m_treeCount, "ProceduralTree");
            PopulateVegetation(scene, GrassMeshUUIDs, m_grassCount, "ProceduralGrass");
            PopulateVegetation(scene, BushMeshUUIDs, m_bushCount, "ProceduralBush");

            m_log.Info($"[PROC_WORLD] Generierung für {scene.RegionInfo.RegionName} erfolgreich abgeschlossen!");
        }

        public void RemoveRegion(Scene scene) { }

        public void Close() { }

        public string Name => "ProceduralWorldModule";
        public Type ReplaceableInterface => null;

        #endregion

        #region Prozedurale Logik

        private void GenerateTerrain(Scene scene)
        {
            ITerrainModule terrainModule = scene.RequestModuleInterface<ITerrainModule>();
            if (terrainModule == null) return;

            ITerrainChannel channel = scene.Heightmap;
            int sizeX = scene.RegionInfo.RegionSizeX;
            int sizeY = scene.RegionInfo.RegionSizeY;

            // Basis-Terrain laden (eine sanfte Sinuswellen-Ebene) und leicht aufrauen (Rauschen)
            for (int x = 0; x < sizeX; x++)
            {
                for (int y = 0; y < sizeY; y++)
                {
                    // Erzeugt eine sanfte Hügellandschaft
                    double baseHeight = 20.0 + Math.Sin(x * 0.05) * Math.Cos(y * 0.05) * 4.0;
                    // Der "Rauheits"-Faktor (Noise)
                    double roughness = (m_rnd.NextDouble() - 0.5) * 0.4; 

                    channel[x, y] = (float)(baseHeight + roughness);
                }
            }
            
            // Dem Server signalisieren, dass sich das Terrain geändert hat, um es an die Viewer zu streamen
            terrainModule.CheckTerrainUpdates();
        }

        private void ApplyTerrainMaterials(Scene scene)
        {
            // Setzt die 4 Textur-IDs direkt im RegionInfo-Protokoll des Simulators fest
            scene.RegionInfo.RegionSettings.TerrainTexture1 = TerrainMaterials[0];
            scene.RegionInfo.RegionSettings.TerrainTexture2 = TerrainMaterials[1];
            scene.RegionInfo.RegionSettings.TerrainTexture3 = TerrainMaterials[2];
            scene.RegionInfo.RegionSettings.TerrainTexture4 = TerrainMaterials[3];

            // Optionale Definition der Höhengrenzen (Regelt, ab welcher Höhe/Steigung welches Material greift)
            scene.RegionInfo.RegionSettings.Elevation1NW = 10;
            scene.RegionInfo.RegionSettings.Elevation2NW = 20;
            scene.RegionInfo.RegionSettings.Elevation1SE = 10;
            scene.RegionInfo.RegionSettings.Elevation2SE = 20;

            scene.RegionInfo.RegionSettings.Save();
        }

        private void PopulateVegetation(Scene scene, UUID[] meshPool, int count, string objectGroupName)
        {
            int sizeX = scene.RegionInfo.RegionSizeX;
            int sizeY = scene.RegionInfo.RegionSizeY;

            for (int i = 0; i < count; i++)
            {
                // Zufällige x/y Koordinaten innerhalb der Regionsgrenzen generieren
                float x = (float)(m_rnd.NextDouble() * (sizeX - 4) + 2);
                float y = (float)(m_rnd.NextDouble() * (sizeY - 4) + 2);
                
                // Exakte Live-Höhe des prozeduralen Terrains an diesem Punkt abfragen
                float z = scene.Heightmap[(int)x, (int)y];

                // Wasserlinie ignorieren (Kein Gras/Baum unter Wasserlinie rezzen, z.B. unter 20m)
                if (z < 20.0f) continue; 

                // Zufälligen Mesh-Typ aus dem Pool der 4 Varianten wählen
                UUID selectedMeshUUID = meshPool[m_rnd.Next(0, 4)];

                // Zufällige Größe (Random bis zur Maximalhöhe) berechnen
                float randomScaleZ = (float)(m_rnd.NextDouble() * (m_maxVegetationHeight - 0.5f) + 0.5f);
                // Proportionale Breite/Tiefe basierend auf der Höhe
                Vector3 scale = new Vector3(randomScaleZ * 0.6f, randomScaleZ * 0.6f, randomScaleZ); 

                // Zufällige Rotation um die Z-Achse (damit Vegetation nicht einheitlich aussieht)
                Quaternion rotation = Quaternion.CreateFromEislerAngles(0, 0, (float)(m_rnd.NextDouble() * Math.PI * 2));

                // Positionierungvektor bestimmen
                Vector3 position = new Vector3(x, y, z);

                // Instanziierung & mathematische Injektion des Meshes in das OpenSim-Szenen-Objektmodell
                CreateMeshObject(scene, selectedMeshUUID, position, scale, rotation, objectGroupName);
            }
        }

        private void CreateMeshObject(Scene scene, UUID assetID, Vector3 pos, Vector3 scale, Quaternion rot, string name)
        {
            // UUIDs für das neue Szenen-Objekt und die Primitives generieren
            UUID ownerID = scene.RegionInfo.MasterAvatarAssignedUUID; // Standardmäßig dem Region-Besitzer zuweisen
            
            // Ein leeres Basis-Prim erstellen (OpenSim benötigt PrimitiveBaseShape als Träger des Assets)
            PrimitiveBaseShape shape = PrimitiveBaseShape.CreateBox();
            
            // Dem Prim sagen, dass es ein skulptiertes/Mesh-Objekt ist und die Asset-ID zuweisen
            shape.SculptEntry = true;
            shape.SculptTexture = assetID;
            shape.SculptType = (byte)SculptType.Mesh; // Wichtig: Deklaration als echtes Asset-Mesh

            // Erstellen der SceneObjectGroup (Das eigentliche physikalische/visuelle 3D-Objekt im Grid)
            SceneObjectGroup sog = new SceneObjectGroup(ownerID, pos, rot, shape);
            sog.Name = name;
            
            // Root-Part Eigenschaften anpassen (Größe, Physik deaktivieren für Performance)
            SceneObjectPart rootPart = sog.RootPart;
            rootPart.Scale = scale;
            rootPart.Flags &= ~PrimFlags.Physics; // Vegetation benötigt keine rechenintensive Havok/ODE Physik
            rootPart.Description = "Procedurally Generated by Addon Module";

            // Objekt permanent in der Szene verankern und an die Datenbank übergeben (Persistence)
            scene.AddNewSceneObject(sog, true);
        }

#endregion
}
}
```

---

### Konfiguration des Moduls (`OpenSim.ini`)

Um die Parameter direkt steuerbar zu machen, fügen Sie folgenden Block unten in Ihre `OpenSim.ini` ein. Das Modul liest diese Werte beim Starten der Regionen automatisch ein:

```ini
[ProceduralWorld]
    Enabled = true
    TreeCount = 250
    GrassCount = 600
    BushCount = 150
    MaxHeight = 12.0
```

---

## Automatische Generierung beim Erstellen neuer Regionen
Das Modul fängt die Methode RegionLoaded ab. Das bedeutet: [2] 

   1. Wenn der Server startet oder Sie ingame/über die Konsole den Befehl create region ausführen, um eine neue Region hinzuzufügen, wird dieses Modul für jede neue Region vollautomatisch isoliert gestartet.
   2. Das Terrain wird frisch berechnet (GenerateTerrain).
   3. Die 4 Materialien werden auf die Oberflächen-Shader gemappt.
   4. Die von Ihnen via Parameter definierte Anzahl von Bäumen, Gräsern und Büschen wird über mathematische Höhenabgleiche (scene.Heightmap[x,y]) exakt auf der Oberfläche platziert, skaliert und zufällig rotiert.

## Kompilieren
Fügen Sie den Ordner zu Ihrer prebuild.xml im OpenSim-Stammverzeichnis hinzu (wie in der Anleitung von OpenSimBirds beschrieben) und führen Sie ./runprebuild.sh (Linux) oder runprebuild.bat (Windows) aus. Kompilieren Sie das Grid anschließend neu. [1] 
Möchten Sie, dass bestimmte Vegetationstypen nur auf bestimmten Texturen/Materialien wachsen (z.B. Palmen nur auf dem Sand-Material)? Ich kann Ihnen dafür eine texturabhängige Höhen- und Steigungsvalidierung in den Code einbauen.

[1] [https://github.com](https://github.com/JakDaniels/OpenSimBirds)
[2] [https://github.com](https://github.com/JakDaniels)

