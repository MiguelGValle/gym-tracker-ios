package com.codex.gymtracker.data

object ExerciseSeed {
    val muscleGroups = listOf(
        "Pectoral clavicular",
        "Pectoral esternal",
        "Dorsal ancho",
        "Trapecio superior",
        "Trapecio medio",
        "Trapecio inferior",
        "Romboides",
        "Erectores espinales",
        "Deltoide anterior",
        "Deltoide medio",
        "Deltoide posterior",
        "Manguito rotador",
        "Biceps",
        "Braquial",
        "Braquiorradial",
        "Triceps cabeza larga",
        "Triceps lateral",
        "Triceps medial",
        "Flexores antebrazo",
        "Extensores antebrazo",
        "Cuadriceps",
        "Isquiosurales",
        "Gluteo mayor",
        "Gluteo medio",
        "Aductores",
        "Abductores",
        "Gemelos",
        "Soleo",
        "Tibial anterior",
        "Recto abdominal",
        "Oblicuos",
        "Transverso",
        "Lumbar"
    )

    val exercises = listOf(
        chest("Press banca barra", "Barra", mapOf("Pectoral esternal" to 50, "Pectoral clavicular" to 15, "Deltoide anterior" to 20, "Triceps lateral" to 10, "Triceps medial" to 5)),
        chest("Press banca mancuernas", "Mancuernas", mapOf("Pectoral esternal" to 50, "Pectoral clavicular" to 15, "Deltoide anterior" to 20, "Triceps lateral" to 10, "Triceps medial" to 5)),
        chest("Press inclinado barra", "Barra", mapOf("Pectoral clavicular" to 45, "Pectoral esternal" to 20, "Deltoide anterior" to 25, "Triceps lateral" to 7, "Triceps medial" to 3)),
        chest("Press inclinado mancuernas", "Mancuernas", mapOf("Pectoral clavicular" to 45, "Pectoral esternal" to 20, "Deltoide anterior" to 25, "Triceps lateral" to 7, "Triceps medial" to 3)),
        chest("Press declinado", "Barra", mapOf("Pectoral esternal" to 60, "Pectoral clavicular" to 5, "Deltoide anterior" to 15, "Triceps lateral" to 12, "Triceps medial" to 8)),
        chest("Aperturas mancuernas", "Mancuernas", mapOf("Pectoral esternal" to 70, "Pectoral clavicular" to 20, "Deltoide anterior" to 10)),
        chest("Aperturas maquina", "Maquina", mapOf("Pectoral esternal" to 75, "Pectoral clavicular" to 15, "Deltoide anterior" to 10)),
        chest("Cruce poleas alto", "Polea", mapOf("Pectoral esternal" to 70, "Pectoral clavicular" to 10, "Deltoide anterior" to 10, "Recto abdominal" to 10)),
        chest("Cruce poleas bajo", "Polea", mapOf("Pectoral clavicular" to 55, "Pectoral esternal" to 25, "Deltoide anterior" to 15, "Recto abdominal" to 5)),
        chest("Fondos pecho", "Peso corporal", mapOf("Pectoral esternal" to 45, "Triceps lateral" to 20, "Triceps medial" to 10, "Deltoide anterior" to 15, "Recto abdominal" to 10)),
        chest("Flexiones", "Peso corporal", mapOf("Pectoral esternal" to 45, "Pectoral clavicular" to 10, "Deltoide anterior" to 20, "Triceps lateral" to 15, "Triceps medial" to 10)),

        back("Dominadas pronas", "Peso corporal", mapOf("Dorsal ancho" to 45, "Biceps" to 15, "Braquial" to 10, "Romboides" to 15, "Trapecio inferior" to 10, "Braquiorradial" to 5)),
        back("Dominadas supinas", "Peso corporal", mapOf("Dorsal ancho" to 40, "Biceps" to 25, "Braquial" to 10, "Romboides" to 10, "Trapecio inferior" to 10, "Braquiorradial" to 5)),
        back("Jalon al pecho", "Polea", mapOf("Dorsal ancho" to 50, "Biceps" to 15, "Braquial" to 10, "Romboides" to 10, "Trapecio inferior" to 10, "Braquiorradial" to 5)),
        back("Jalon agarre neutro", "Polea", mapOf("Dorsal ancho" to 45, "Biceps" to 15, "Braquial" to 10, "Romboides" to 15, "Trapecio inferior" to 10, "Braquiorradial" to 5)),
        back("Remo barra", "Barra", mapOf("Dorsal ancho" to 25, "Romboides" to 20, "Trapecio medio" to 20, "Deltoide posterior" to 10, "Biceps" to 10, "Erectores espinales" to 15)),
        back("Remo mancuerna", "Mancuerna", mapOf("Dorsal ancho" to 35, "Romboides" to 20, "Trapecio medio" to 15, "Deltoide posterior" to 10, "Biceps" to 10, "Oblicuos" to 10)),
        back("Remo polea sentado", "Polea", mapOf("Dorsal ancho" to 30, "Romboides" to 25, "Trapecio medio" to 20, "Deltoide posterior" to 10, "Biceps" to 10, "Braquial" to 5)),
        back("Remo pecho apoyado", "Maquina", mapOf("Dorsal ancho" to 30, "Romboides" to 25, "Trapecio medio" to 20, "Deltoide posterior" to 15, "Biceps" to 10)),
        back("Pullover polea", "Polea", mapOf("Dorsal ancho" to 70, "Triceps cabeza larga" to 10, "Pectoral esternal" to 5, "Recto abdominal" to 10, "Lumbar" to 5)),
        back("Peso muerto convencional", "Barra", mapOf("Erectores espinales" to 25, "Gluteo mayor" to 25, "Isquiosurales" to 20, "Cuadriceps" to 15, "Trapecio superior" to 10, "Flexores antebrazo" to 5)),
        back("Hiperextensiones", "Banco", mapOf("Erectores espinales" to 45, "Gluteo mayor" to 30, "Isquiosurales" to 20, "Lumbar" to 5)),

        shoulder("Press militar barra", "Barra", mapOf("Deltoide anterior" to 45, "Deltoide medio" to 20, "Triceps lateral" to 15, "Triceps medial" to 10, "Trapecio superior" to 10)),
        shoulder("Press hombro mancuernas", "Mancuernas", mapOf("Deltoide anterior" to 40, "Deltoide medio" to 25, "Triceps lateral" to 15, "Triceps medial" to 10, "Trapecio superior" to 10)),
        shoulder("Elevacion lateral", "Mancuernas", mapOf("Deltoide medio" to 80, "Trapecio superior" to 10, "Manguito rotador" to 10)),
        shoulder("Elevacion lateral polea", "Polea", mapOf("Deltoide medio" to 85, "Trapecio superior" to 10, "Manguito rotador" to 5)),
        shoulder("Elevacion frontal", "Mancuernas", mapOf("Deltoide anterior" to 75, "Pectoral clavicular" to 15, "Trapecio superior" to 10)),
        shoulder("Pajaro mancuernas", "Mancuernas", mapOf("Deltoide posterior" to 70, "Romboides" to 15, "Trapecio medio" to 10, "Trapecio inferior" to 5)),
        shoulder("Face pull", "Polea", mapOf("Deltoide posterior" to 40, "Romboides" to 20, "Trapecio medio" to 20, "Trapecio inferior" to 10, "Manguito rotador" to 10)),
        shoulder("Encogimientos barra", "Barra", mapOf("Trapecio superior" to 80, "Flexores antebrazo" to 10, "Erectores espinales" to 10)),

        legs("Sentadilla barra", "Barra", mapOf("Cuadriceps" to 35, "Gluteo mayor" to 30, "Aductores" to 10, "Isquiosurales" to 10, "Erectores espinales" to 10, "Recto abdominal" to 5)),
        legs("Sentadilla frontal", "Barra", mapOf("Cuadriceps" to 50, "Gluteo mayor" to 20, "Aductores" to 10, "Erectores espinales" to 10, "Recto abdominal" to 10)),
        legs("Prensa de piernas", "Maquina", mapOf("Cuadriceps" to 45, "Gluteo mayor" to 30, "Aductores" to 10, "Isquiosurales" to 10, "Gemelos" to 5)),
        legs("Hack squat", "Maquina", mapOf("Cuadriceps" to 55, "Gluteo mayor" to 25, "Aductores" to 10, "Isquiosurales" to 5, "Gemelos" to 5)),
        legs("Zancadas", "Mancuernas", mapOf("Gluteo mayor" to 35, "Cuadriceps" to 35, "Isquiosurales" to 10, "Gluteo medio" to 10, "Aductores" to 10)),
        legs("Bulgarian split squat", "Mancuernas", mapOf("Cuadriceps" to 40, "Gluteo mayor" to 35, "Gluteo medio" to 10, "Aductores" to 10, "Isquiosurales" to 5)),
        legs("Hip thrust", "Barra", mapOf("Gluteo mayor" to 70, "Isquiosurales" to 15, "Cuadriceps" to 5, "Erectores espinales" to 5, "Recto abdominal" to 5)),
        legs("Peso muerto rumano", "Barra", mapOf("Isquiosurales" to 45, "Gluteo mayor" to 35, "Erectores espinales" to 15, "Flexores antebrazo" to 5)),
        legs("Curl femoral tumbado", "Maquina", mapOf("Isquiosurales" to 85, "Gemelos" to 10, "Gluteo mayor" to 5)),
        legs("Curl femoral sentado", "Maquina", mapOf("Isquiosurales" to 88, "Gemelos" to 7, "Gluteo mayor" to 5)),
        legs("Extension de pierna", "Maquina", mapOf("Cuadriceps" to 100)),
        legs("Gemelo de pie", "Maquina", mapOf("Gemelos" to 75, "Soleo" to 20, "Tibial anterior" to 5)),
        legs("Gemelo sentado", "Maquina", mapOf("Soleo" to 70, "Gemelos" to 30)),
        legs("Aductor maquina", "Maquina", mapOf("Aductores" to 90, "Gluteo mayor" to 5, "Recto abdominal" to 5)),
        legs("Abductor maquina", "Maquina", mapOf("Abductores" to 70, "Gluteo medio" to 25, "Recto abdominal" to 5)),

        arms("Curl barra", "Barra", mapOf("Biceps" to 60, "Braquial" to 20, "Braquiorradial" to 10, "Flexores antebrazo" to 10)),
        arms("Curl mancuernas", "Mancuernas", mapOf("Biceps" to 60, "Braquial" to 20, "Braquiorradial" to 10, "Flexores antebrazo" to 10)),
        arms("Curl predicador", "Maquina", mapOf("Biceps" to 65, "Braquial" to 20, "Braquiorradial" to 10, "Flexores antebrazo" to 5)),
        arms("Curl martillo", "Mancuernas", mapOf("Braquiorradial" to 45, "Braquial" to 35, "Biceps" to 15, "Flexores antebrazo" to 5)),
        arms("Curl polea", "Polea", mapOf("Biceps" to 65, "Braquial" to 20, "Braquiorradial" to 10, "Flexores antebrazo" to 5)),
        arms("Extension triceps polea", "Polea", mapOf("Triceps lateral" to 45, "Triceps medial" to 35, "Triceps cabeza larga" to 20)),
        arms("Press frances", "Barra", mapOf("Triceps cabeza larga" to 45, "Triceps lateral" to 30, "Triceps medial" to 25)),
        arms("Fondos triceps", "Peso corporal", mapOf("Triceps lateral" to 35, "Triceps medial" to 25, "Triceps cabeza larga" to 20, "Pectoral esternal" to 10, "Deltoide anterior" to 10)),
        arms("Extension triceps sobre cabeza", "Mancuerna", mapOf("Triceps cabeza larga" to 55, "Triceps lateral" to 25, "Triceps medial" to 20)),

        core("Crunch", "Peso corporal", mapOf("Recto abdominal" to 70, "Oblicuos" to 15, "Transverso" to 15)),
        core("Crunch polea", "Polea", mapOf("Recto abdominal" to 75, "Oblicuos" to 15, "Transverso" to 10)),
        core("Elevacion de piernas", "Peso corporal", mapOf("Recto abdominal" to 55, "Oblicuos" to 15, "Transverso" to 20, "Cuadriceps" to 10)),
        core("Plancha", "Peso corporal", mapOf("Transverso" to 35, "Recto abdominal" to 30, "Oblicuos" to 20, "Gluteo mayor" to 10, "Deltoide anterior" to 5)),
        core("Pallof press", "Polea", mapOf("Oblicuos" to 45, "Transverso" to 35, "Recto abdominal" to 10, "Deltoide anterior" to 10)),
        core("Russian twist", "Peso corporal", mapOf("Oblicuos" to 55, "Recto abdominal" to 25, "Transverso" to 20)),
        core("Rueda abdominal", "Rueda", mapOf("Recto abdominal" to 45, "Transverso" to 25, "Oblicuos" to 15, "Dorsal ancho" to 10, "Deltoide anterior" to 5)),

        cardio("Cinta", "Cardio", mapOf("Cuadriceps" to 25, "Gluteo mayor" to 20, "Isquiosurales" to 20, "Gemelos" to 20, "Soleo" to 10, "Recto abdominal" to 5)),
        cardio("Bicicleta estatica", "Cardio", mapOf("Cuadriceps" to 45, "Gluteo mayor" to 20, "Isquiosurales" to 15, "Gemelos" to 10, "Soleo" to 10)),
        cardio("Eliptica", "Cardio", mapOf("Cuadriceps" to 30, "Gluteo mayor" to 20, "Isquiosurales" to 15, "Gemelos" to 15, "Deltoide posterior" to 10, "Dorsal ancho" to 10)),
        cardio("Remo ergometro", "Cardio", mapOf("Dorsal ancho" to 25, "Cuadriceps" to 25, "Gluteo mayor" to 15, "Isquiosurales" to 15, "Biceps" to 10, "Recto abdominal" to 10)),
        cardio("Stair climber", "Cardio", mapOf("Gluteo mayor" to 35, "Cuadriceps" to 30, "Isquiosurales" to 15, "Gemelos" to 10, "Soleo" to 10)),
        cardio("Ski erg", "Cardio", mapOf("Dorsal ancho" to 30, "Triceps cabeza larga" to 15, "Recto abdominal" to 15, "Gluteo mayor" to 15, "Isquiosurales" to 10, "Deltoide posterior" to 15)),

        technogym("Selection 900 Leg Press", "Technogym Selection 900", "Pierna", "Empuje pierna", mapOf("Cuadriceps" to 45, "Gluteo mayor" to 30, "Aductores" to 10, "Isquiosurales" to 10, "Gemelos" to 5)),
        technogym("Selection 900 Leg Extension", "Technogym Selection 900", "Pierna", "Extension rodilla", mapOf("Cuadriceps" to 100)),
        technogym("Selection 900 Leg Curl", "Technogym Selection 900", "Pierna", "Flexion rodilla", mapOf("Isquiosurales" to 88, "Gemelos" to 7, "Gluteo mayor" to 5)),
        technogym("Selection 900 Chest Press", "Technogym Selection 900", "Pecho", "Empuje horizontal", mapOf("Pectoral esternal" to 55, "Deltoide anterior" to 20, "Triceps lateral" to 15, "Triceps medial" to 10)),
        technogym("Selection 900 Pectoral", "Technogym Selection 900", "Pecho", "Aduccion hombro", mapOf("Pectoral esternal" to 75, "Pectoral clavicular" to 15, "Deltoide anterior" to 10)),
        technogym("Selection 900 Shoulder Press", "Technogym Selection 900", "Hombro", "Empuje vertical", mapOf("Deltoide anterior" to 45, "Deltoide medio" to 25, "Triceps lateral" to 15, "Triceps medial" to 10, "Trapecio superior" to 5)),
        technogym("Selection 900 Lat Machine", "Technogym Selection 900", "Espalda", "Traccion vertical", mapOf("Dorsal ancho" to 50, "Biceps" to 15, "Braquial" to 10, "Romboides" to 10, "Trapecio inferior" to 10, "Braquiorradial" to 5)),
        technogym("Selection 900 Vertical Traction", "Technogym Selection 900", "Espalda", "Traccion vertical", mapOf("Dorsal ancho" to 45, "Romboides" to 15, "Trapecio medio" to 15, "Biceps" to 15, "Braquial" to 10)),
        technogym("Selection 900 Low Row", "Technogym Selection 900", "Espalda", "Remo", mapOf("Dorsal ancho" to 30, "Romboides" to 25, "Trapecio medio" to 20, "Deltoide posterior" to 10, "Biceps" to 10, "Braquial" to 5)),
        technogym("Selection 900 Pulley", "Technogym Selection 900", "Espalda", "Remo polea", mapOf("Dorsal ancho" to 30, "Romboides" to 25, "Trapecio medio" to 20, "Deltoide posterior" to 10, "Biceps" to 10, "Braquial" to 5)),
        technogym("Selection 900 Cable Crossover", "Technogym Selection 900", "Pecho", "Polea libre", mapOf("Pectoral esternal" to 55, "Pectoral clavicular" to 15, "Deltoide anterior" to 10, "Recto abdominal" to 10, "Oblicuos" to 10)),
        technogym("Selection 900 Abdominal Crunch", "Technogym Selection 900", "Core", "Flexion tronco", mapOf("Recto abdominal" to 75, "Oblicuos" to 15, "Transverso" to 10)),
        technogym("Selection 900 Lower Back", "Technogym Selection 900", "Core", "Extension tronco", mapOf("Erectores espinales" to 60, "Gluteo mayor" to 20, "Isquiosurales" to 15, "Lumbar" to 5)),
        technogym("Selection 900 Abductor", "Technogym Selection 900", "Pierna", "Abduccion cadera", mapOf("Abductores" to 70, "Gluteo medio" to 25, "Recto abdominal" to 5)),
        technogym("Selection 900 Adductor", "Technogym Selection 900", "Pierna", "Aduccion cadera", mapOf("Aductores" to 90, "Gluteo mayor" to 5, "Recto abdominal" to 5)),
        technogym("Selection 900 Arm Curl", "Technogym Selection 900", "Brazos", "Flexion codo", mapOf("Biceps" to 65, "Braquial" to 20, "Braquiorradial" to 10, "Flexores antebrazo" to 5)),
        technogym("Selection 900 Arm Extension", "Technogym Selection 900", "Brazos", "Extension codo", mapOf("Triceps lateral" to 40, "Triceps medial" to 35, "Triceps cabeza larga" to 25)),
        technogym("Selection 900 Kneeling Chin Dip", "Technogym Selection 900", "Mixto", "Asistida", mapOf("Dorsal ancho" to 35, "Pectoral esternal" to 20, "Triceps lateral" to 15, "Biceps" to 15, "Deltoide anterior" to 10, "Recto abdominal" to 5)),
        technogym("Selection 900 Smith Machine", "Technogym Selection 900", "Mixto", "Multipower", mapOf("Cuadriceps" to 35, "Gluteo mayor" to 25, "Pectoral esternal" to 20, "Deltoide anterior" to 10, "Triceps lateral" to 10)),
        technogym("Selection 900 Chin Up Dip Leg Raise", "Technogym Selection 900", "Mixto", "Peso corporal", mapOf("Dorsal ancho" to 30, "Triceps lateral" to 15, "Pectoral esternal" to 15, "Recto abdominal" to 25, "Oblicuos" to 10, "Biceps" to 5)),

        technogym("Biostrength Leg Press", "Technogym Biostrength", "Pierna", "Empuje pierna", mapOf("Cuadriceps" to 45, "Gluteo mayor" to 30, "Aductores" to 10, "Isquiosurales" to 10, "Gemelos" to 5)),
        technogym("Biostrength Chest Press", "Technogym Biostrength", "Pecho", "Empuje horizontal", mapOf("Pectoral esternal" to 55, "Deltoide anterior" to 20, "Triceps lateral" to 15, "Triceps medial" to 10)),
        technogym("Biostrength Shoulder Press", "Technogym Biostrength", "Hombro", "Empuje vertical", mapOf("Deltoide anterior" to 45, "Deltoide medio" to 25, "Triceps lateral" to 15, "Triceps medial" to 10, "Trapecio superior" to 5)),
        technogym("Biostrength Vertical Traction", "Technogym Biostrength", "Espalda", "Traccion vertical", mapOf("Dorsal ancho" to 45, "Romboides" to 15, "Trapecio medio" to 15, "Biceps" to 15, "Braquial" to 10)),
        technogym("Biostrength Low Row", "Technogym Biostrength", "Espalda", "Remo", mapOf("Dorsal ancho" to 30, "Romboides" to 25, "Trapecio medio" to 20, "Deltoide posterior" to 10, "Biceps" to 10, "Braquial" to 5)),
        technogym("Biostrength Leg Extension", "Technogym Biostrength", "Pierna", "Extension rodilla", mapOf("Cuadriceps" to 100)),
        technogym("Biostrength Leg Curl", "Technogym Biostrength", "Pierna", "Flexion rodilla", mapOf("Isquiosurales" to 88, "Gemelos" to 7, "Gluteo mayor" to 5)),
        technogym("Biostrength Abductor", "Technogym Biostrength", "Pierna", "Abduccion cadera", mapOf("Abductores" to 70, "Gluteo medio" to 25, "Recto abdominal" to 5)),
        technogym("Biostrength Adductor", "Technogym Biostrength", "Pierna", "Aduccion cadera", mapOf("Aductores" to 90, "Gluteo mayor" to 5, "Recto abdominal" to 5)),
        technogym("Biostrength Abdominal Crunch", "Technogym Biostrength", "Core", "Flexion tronco", mapOf("Recto abdominal" to 75, "Oblicuos" to 15, "Transverso" to 10)),

        technogym("Unica Chest Press", "Technogym Unica", "Pecho", "Empuje horizontal", mapOf("Pectoral esternal" to 55, "Deltoide anterior" to 20, "Triceps lateral" to 15, "Triceps medial" to 10)),
        technogym("Unica Lat Pulldown", "Technogym Unica", "Espalda", "Traccion vertical", mapOf("Dorsal ancho" to 50, "Biceps" to 15, "Braquial" to 10, "Romboides" to 10, "Trapecio inferior" to 10, "Braquiorradial" to 5)),
        technogym("Unica Low Row", "Technogym Unica", "Espalda", "Remo", mapOf("Dorsal ancho" to 30, "Romboides" to 25, "Trapecio medio" to 20, "Deltoide posterior" to 10, "Biceps" to 10, "Braquial" to 5)),
        technogym("Unica Leg Extension", "Technogym Unica", "Pierna", "Extension rodilla", mapOf("Cuadriceps" to 100)),
        technogym("Unica Leg Curl", "Technogym Unica", "Pierna", "Flexion rodilla", mapOf("Isquiosurales" to 88, "Gemelos" to 7, "Gluteo mayor" to 5)),
        technogym("Unica Arm Curl", "Technogym Unica", "Brazos", "Flexion codo", mapOf("Biceps" to 65, "Braquial" to 20, "Braquiorradial" to 10, "Flexores antebrazo" to 5)),
        technogym("Unica Triceps Pushdown", "Technogym Unica", "Brazos", "Extension codo", mapOf("Triceps lateral" to 40, "Triceps medial" to 35, "Triceps cabeza larga" to 25))
    )

    private fun chest(name: String, equipment: String, muscles: Map<String, Int>) =
        SeedExercise(name, equipment, "Pecho", "Empuje", muscles = muscles)

    private fun back(name: String, equipment: String, muscles: Map<String, Int>) =
        SeedExercise(name, equipment, "Espalda", "Traccion", muscles = muscles)

    private fun shoulder(name: String, equipment: String, muscles: Map<String, Int>) =
        SeedExercise(name, equipment, "Hombro", "Empuje/aislamiento", muscles = muscles)

    private fun legs(name: String, equipment: String, muscles: Map<String, Int>) =
        SeedExercise(name, equipment, "Pierna", "Pierna", muscles = muscles)

    private fun arms(name: String, equipment: String, muscles: Map<String, Int>) =
        SeedExercise(name, equipment, "Brazos", "Aislamiento", muscles = muscles)

    private fun core(name: String, equipment: String, muscles: Map<String, Int>) =
        SeedExercise(name, equipment, "Core", "Core", muscles = muscles)

    private fun cardio(name: String, equipment: String, muscles: Map<String, Int>) =
        SeedExercise(name, equipment, "Cardio", "Cardio", muscles = muscles)

    private fun technogym(
        name: String,
        equipment: String,
        category: String,
        movement: String,
        muscles: Map<String, Int>
    ) = SeedExercise(name, equipment, category, movement, technogym = true, muscles = muscles)
}
