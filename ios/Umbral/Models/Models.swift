import Foundation

// MARK: - data/*.json (WHOOP sync, solo lectura)

struct WorkoutEntry: Codable, Hashable {
    let sportName: String?
    let strain: Double?
    let averageHeartRate: Int?
    let durationMin: Int?

    enum CodingKeys: String, CodingKey {
        case sportName = "sport_name"
        case strain
        case averageHeartRate = "average_heart_rate"
        case durationMin = "duration_min"
    }
}

struct DayRecord: Codable, Identifiable, Hashable {
    var id: String { date }
    let date: String
    let notes: String?
    let photos: [String]?
    let tipo: String?
    let etiquetas: [String]?
    let recoveryScore: Double?
    let hrvRmssdMilli: Double?
    let restingHeartRate: Double?
    let dayStrain: Double?
    let sleepPerformancePercentage: Double?
    let sleepEfficiencyPercentage: Double?
    let workouts: [WorkoutEntry]?

    enum CodingKeys: String, CodingKey {
        case date, notes, photos, tipo, etiquetas
        case recoveryScore = "recovery_score"
        case hrvRmssdMilli = "hrv_rmssd_milli"
        case restingHeartRate = "resting_heart_rate"
        case dayStrain = "day_strain"
        case sleepPerformancePercentage = "sleep_performance_percentage"
        case sleepEfficiencyPercentage = "sleep_efficiency_percentage"
        case workouts
    }

    /// Memberwise init — necesario porque el init(from:) de abajo lo suprime.
    /// Se usa para construir un DayRecord a partir de una lectura en vivo de WHOOP.
    init(date: String, notes: String? = nil, photos: [String]? = nil, tipo: String? = nil,
         etiquetas: [String]? = nil, recoveryScore: Double? = nil, hrvRmssdMilli: Double? = nil,
         restingHeartRate: Double? = nil, dayStrain: Double? = nil,
         sleepPerformancePercentage: Double? = nil, sleepEfficiencyPercentage: Double? = nil,
         workouts: [WorkoutEntry]? = nil) {
        self.date = date
        self.notes = notes
        self.photos = photos
        self.tipo = tipo
        self.etiquetas = etiquetas
        self.recoveryScore = recoveryScore
        self.hrvRmssdMilli = hrvRmssdMilli
        self.restingHeartRate = restingHeartRate
        self.dayStrain = dayStrain
        self.sleepPerformancePercentage = sleepPerformancePercentage
        self.sleepEfficiencyPercentage = sleepEfficiencyPercentage
        self.workouts = workouts
    }

    /// Combina esta lectura (normalmente cacheada de GitHub) con una lectura en
    /// vivo de WHOOP: conserva notas/fotos propias, prioriza los números frescos.
    func mergingLiveWhoop(_ live: DayRecord) -> DayRecord {
        DayRecord(
            date: date, notes: notes, photos: photos, tipo: tipo, etiquetas: etiquetas,
            recoveryScore: live.recoveryScore ?? recoveryScore,
            hrvRmssdMilli: live.hrvRmssdMilli ?? hrvRmssdMilli,
            restingHeartRate: live.restingHeartRate ?? restingHeartRate,
            dayStrain: live.dayStrain ?? dayStrain,
            sleepPerformancePercentage: live.sleepPerformancePercentage ?? sleepPerformancePercentage,
            sleepEfficiencyPercentage: live.sleepEfficiencyPercentage ?? sleepEfficiencyPercentage,
            workouts: live.workouts ?? workouts
        )
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        photos = try c.decodeIfPresent([String].self, forKey: .photos)
        tipo = try c.decodeIfPresent(String.self, forKey: .tipo)
        etiquetas = try c.decodeIfPresent([String].self, forKey: .etiquetas)
        recoveryScore = try c.decodeIfPresent(Double.self, forKey: .recoveryScore)
        hrvRmssdMilli = try c.decodeIfPresent(Double.self, forKey: .hrvRmssdMilli)
        restingHeartRate = try c.decodeIfPresent(Double.self, forKey: .restingHeartRate)
        dayStrain = try c.decodeIfPresent(Double.self, forKey: .dayStrain)
        sleepPerformancePercentage = try c.decodeIfPresent(Double.self, forKey: .sleepPerformancePercentage)
        sleepEfficiencyPercentage = try c.decodeIfPresent(Double.self, forKey: .sleepEfficiencyPercentage)
        workouts = try c.decodeIfPresent([WorkoutEntry].self, forKey: .workouts)
    }
}

// MARK: - data/planes.json (lectura + escritura)

struct DayPlanEntry: Codable, Hashable {
    var titulo: String?
    var disciplina: String?
    var zonaObjetivo: Int?
    var rpe: Int?
    var duracionPrevista: Int?
    var descripcion: String?
    var resultado: String?
    var sensaciones: String?

    enum CodingKeys: String, CodingKey {
        case titulo, disciplina
        case zonaObjetivo = "zona_objetivo"
        case rpe
        case duracionPrevista = "duracion_prevista"
        case descripcion, resultado, sensaciones
    }

    init(titulo: String? = nil, disciplina: String? = nil, zonaObjetivo: Int? = nil,
         rpe: Int? = nil, duracionPrevista: Int? = nil, descripcion: String? = nil,
         resultado: String? = nil, sensaciones: String? = nil) {
        self.titulo = titulo
        self.disciplina = disciplina
        self.zonaObjetivo = zonaObjetivo
        self.rpe = rpe
        self.duracionPrevista = duracionPrevista
        self.descripcion = descripcion
        self.resultado = resultado
        self.sensaciones = sensaciones
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        titulo = try c.decodeIfPresent(String.self, forKey: .titulo)
        disciplina = try c.decodeIfPresent(String.self, forKey: .disciplina)
        zonaObjetivo = try c.decodeIfPresent(Int.self, forKey: .zonaObjetivo)
        rpe = try c.decodeIfPresent(Int.self, forKey: .rpe)
        duracionPrevista = try c.decodeIfPresent(Int.self, forKey: .duracionPrevista)
        descripcion = try c.decodeIfPresent(String.self, forKey: .descripcion)
        resultado = try c.decodeIfPresent(String.self, forKey: .resultado)
        sensaciones = try c.decodeIfPresent(String.self, forKey: .sensaciones)
    }
}

struct PlanSemana: Codable, Identifiable, Hashable {
    var id: String { semana }
    var semana: String
    var bloque: String?
    var foco: String?
    var dias: [String: DayPlanEntry]

    enum CodingKeys: String, CodingKey {
        case semana, bloque, foco, dias
    }

    init(semana: String, bloque: String? = nil, foco: String? = nil, dias: [String: DayPlanEntry] = [:]) {
        self.semana = semana
        self.bloque = bloque
        self.foco = foco
        self.dias = dias
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        semana = try c.decode(String.self, forKey: .semana)
        bloque = try c.decodeIfPresent(String.self, forKey: .bloque)
        foco = try c.decodeIfPresent(String.self, forKey: .foco)
        dias = try c.decodeIfPresent([String: DayPlanEntry].self, forKey: .dias) ?? [:]
    }
}

// MARK: - data/records.json (lectura + escritura)

enum RecordTipo: String, Codable, CaseIterable, Identifiable {
    case tiempo, numero, distancia, peso, rondas
    var id: String { rawValue }

    var label: String {
        switch self {
        case .tiempo: return "Tiempo (mm:ss)"
        case .numero: return "Número"
        case .distancia: return "Distancia (km)"
        case .peso: return "Peso (kg)"
        case .rondas: return "Rondas"
        }
    }

    var menorMejor: Bool { self == .tiempo }

    /// Formatea un valor almacenado (segundos para tiempo) a texto legible.
    func format(_ v: Double) -> String {
        switch self {
        case .tiempo:
            let total = Int(v.rounded())
            return "\(total / 60):\(String(format: "%02d", total % 60))"
        case .numero: return trimZeros(v)
        case .distancia: return "\(trimZeros(v)) km"
        case .peso: return "\(trimZeros(v)) kg"
        case .rondas: return "\(trimZeros(v)) rondas"
        }
    }

    /// Parsea texto introducido por el usuario a valor almacenable.
    func parse(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces)
        switch self {
        case .tiempo:
            let parts = t.split(separator: ":")
            guard parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) else { return nil }
            return Double(m * 60 + s)
        default:
            return Double(t.replacingOccurrences(of: ",", with: "."))
        }
    }

    private func trimZeros(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(v)
    }
}

struct RecordEntry: Codable, Identifiable, Hashable {
    var id: String { "\(fecha)-\(valor)" }
    var fecha: String
    var valor: Double
    var nota: String?
}

struct RecordItem: Codable, Identifiable, Hashable {
    var id: String { "\(disciplina ?? "")-\(nombre ?? "")" }
    var disciplina: String?
    var nombre: String?
    var tipo: RecordTipo
    var historial: [RecordEntry]

    init(disciplina: String?, nombre: String?, tipo: RecordTipo, historial: [RecordEntry] = []) {
        self.disciplina = disciplina
        self.nombre = nombre
        self.tipo = tipo
        self.historial = historial
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        disciplina = try c.decodeIfPresent(String.self, forKey: .disciplina)
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre)
        tipo = try c.decode(RecordTipo.self, forKey: .tipo)
        historial = try c.decodeIfPresent([RecordEntry].self, forKey: .historial) ?? []
    }

    enum CodingKeys: String, CodingKey { case disciplina, nombre, tipo, historial }
}

// MARK: - Sesión derivada (planificado + ejecutado, como S en index.html)

struct SessionEntry: Identifiable, Hashable {
    var id: String { fecha }
    let fecha: String
    let titulo: String
    let disciplina: String
    let cats: [String]
    let desc: String
    let resultado: String
    let sensaciones: String
    let rpe: Int?
    let zonaObjetivo: Int?
    let rec: Double?
    let hrv: Double?
    let strain: Double?
    let sueno: Double?
    let workouts: [WorkoutEntry]
    let hecho: Bool
    let planificado: Bool
    let minutos: Int
}

let DISC_LIST = ["Crossfit", "Hyrox", "Carrera", "Gimnásticos", "Fuerza", "Movilidad", "Descanso"]
