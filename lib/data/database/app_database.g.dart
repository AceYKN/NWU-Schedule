// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SemestersTable extends Semesters
    with TableInfo<$SemestersTable, Semester> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SemestersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _academicYearMeta =
      const VerificationMeta('academicYear');
  @override
  late final GeneratedColumn<String> academicYear = GeneratedColumn<String>(
      'academic_year', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _termMeta = const VerificationMeta('term');
  @override
  late final GeneratedColumn<int> term = GeneratedColumn<int>(
      'term', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _remoteTermKeyMeta =
      const VerificationMeta('remoteTermKey');
  @override
  late final GeneratedColumn<String> remoteTermKey = GeneratedColumn<String>(
      'remote_term_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _calendarIdMeta =
      const VerificationMeta('calendarId');
  @override
  late final GeneratedColumn<String> calendarId = GeneratedColumn<String>(
      'calendar_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _calendarRevisionMeta =
      const VerificationMeta('calendarRevision');
  @override
  late final GeneratedColumn<int> calendarRevision = GeneratedColumn<int>(
      'calendar_revision', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        academicYear,
        term,
        label,
        remoteTermKey,
        calendarId,
        calendarRevision,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'semesters';
  @override
  VerificationContext validateIntegrity(Insertable<Semester> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('academic_year')) {
      context.handle(
          _academicYearMeta,
          academicYear.isAcceptableOrUnknown(
              data['academic_year']!, _academicYearMeta));
    } else if (isInserting) {
      context.missing(_academicYearMeta);
    }
    if (data.containsKey('term')) {
      context.handle(
          _termMeta, term.isAcceptableOrUnknown(data['term']!, _termMeta));
    } else if (isInserting) {
      context.missing(_termMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('remote_term_key')) {
      context.handle(
          _remoteTermKeyMeta,
          remoteTermKey.isAcceptableOrUnknown(
              data['remote_term_key']!, _remoteTermKeyMeta));
    }
    if (data.containsKey('calendar_id')) {
      context.handle(
          _calendarIdMeta,
          calendarId.isAcceptableOrUnknown(
              data['calendar_id']!, _calendarIdMeta));
    }
    if (data.containsKey('calendar_revision')) {
      context.handle(
          _calendarRevisionMeta,
          calendarRevision.isAcceptableOrUnknown(
              data['calendar_revision']!, _calendarRevisionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Semester map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Semester(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      academicYear: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}academic_year'])!,
      term: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}term'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      remoteTermKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_term_key']),
      calendarId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}calendar_id']),
      calendarRevision: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}calendar_revision']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SemestersTable createAlias(String alias) {
    return $SemestersTable(attachedDatabase, alias);
  }
}

class Semester extends DataClass implements Insertable<Semester> {
  final String id;
  final String academicYear;
  final int term;
  final String label;
  final String? remoteTermKey;
  final String? calendarId;
  final int? calendarRevision;
  final DateTime createdAt;
  const Semester(
      {required this.id,
      required this.academicYear,
      required this.term,
      required this.label,
      this.remoteTermKey,
      this.calendarId,
      this.calendarRevision,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['academic_year'] = Variable<String>(academicYear);
    map['term'] = Variable<int>(term);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || remoteTermKey != null) {
      map['remote_term_key'] = Variable<String>(remoteTermKey);
    }
    if (!nullToAbsent || calendarId != null) {
      map['calendar_id'] = Variable<String>(calendarId);
    }
    if (!nullToAbsent || calendarRevision != null) {
      map['calendar_revision'] = Variable<int>(calendarRevision);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SemestersCompanion toCompanion(bool nullToAbsent) {
    return SemestersCompanion(
      id: Value(id),
      academicYear: Value(academicYear),
      term: Value(term),
      label: Value(label),
      remoteTermKey: remoteTermKey == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteTermKey),
      calendarId: calendarId == null && nullToAbsent
          ? const Value.absent()
          : Value(calendarId),
      calendarRevision: calendarRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(calendarRevision),
      createdAt: Value(createdAt),
    );
  }

  factory Semester.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Semester(
      id: serializer.fromJson<String>(json['id']),
      academicYear: serializer.fromJson<String>(json['academicYear']),
      term: serializer.fromJson<int>(json['term']),
      label: serializer.fromJson<String>(json['label']),
      remoteTermKey: serializer.fromJson<String?>(json['remoteTermKey']),
      calendarId: serializer.fromJson<String?>(json['calendarId']),
      calendarRevision: serializer.fromJson<int?>(json['calendarRevision']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'academicYear': serializer.toJson<String>(academicYear),
      'term': serializer.toJson<int>(term),
      'label': serializer.toJson<String>(label),
      'remoteTermKey': serializer.toJson<String?>(remoteTermKey),
      'calendarId': serializer.toJson<String?>(calendarId),
      'calendarRevision': serializer.toJson<int?>(calendarRevision),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Semester copyWith(
          {String? id,
          String? academicYear,
          int? term,
          String? label,
          Value<String?> remoteTermKey = const Value.absent(),
          Value<String?> calendarId = const Value.absent(),
          Value<int?> calendarRevision = const Value.absent(),
          DateTime? createdAt}) =>
      Semester(
        id: id ?? this.id,
        academicYear: academicYear ?? this.academicYear,
        term: term ?? this.term,
        label: label ?? this.label,
        remoteTermKey:
            remoteTermKey.present ? remoteTermKey.value : this.remoteTermKey,
        calendarId: calendarId.present ? calendarId.value : this.calendarId,
        calendarRevision: calendarRevision.present
            ? calendarRevision.value
            : this.calendarRevision,
        createdAt: createdAt ?? this.createdAt,
      );
  Semester copyWithCompanion(SemestersCompanion data) {
    return Semester(
      id: data.id.present ? data.id.value : this.id,
      academicYear: data.academicYear.present
          ? data.academicYear.value
          : this.academicYear,
      term: data.term.present ? data.term.value : this.term,
      label: data.label.present ? data.label.value : this.label,
      remoteTermKey: data.remoteTermKey.present
          ? data.remoteTermKey.value
          : this.remoteTermKey,
      calendarId:
          data.calendarId.present ? data.calendarId.value : this.calendarId,
      calendarRevision: data.calendarRevision.present
          ? data.calendarRevision.value
          : this.calendarRevision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Semester(')
          ..write('id: $id, ')
          ..write('academicYear: $academicYear, ')
          ..write('term: $term, ')
          ..write('label: $label, ')
          ..write('remoteTermKey: $remoteTermKey, ')
          ..write('calendarId: $calendarId, ')
          ..write('calendarRevision: $calendarRevision, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, academicYear, term, label, remoteTermKey,
      calendarId, calendarRevision, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Semester &&
          other.id == this.id &&
          other.academicYear == this.academicYear &&
          other.term == this.term &&
          other.label == this.label &&
          other.remoteTermKey == this.remoteTermKey &&
          other.calendarId == this.calendarId &&
          other.calendarRevision == this.calendarRevision &&
          other.createdAt == this.createdAt);
}

class SemestersCompanion extends UpdateCompanion<Semester> {
  final Value<String> id;
  final Value<String> academicYear;
  final Value<int> term;
  final Value<String> label;
  final Value<String?> remoteTermKey;
  final Value<String?> calendarId;
  final Value<int?> calendarRevision;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SemestersCompanion({
    this.id = const Value.absent(),
    this.academicYear = const Value.absent(),
    this.term = const Value.absent(),
    this.label = const Value.absent(),
    this.remoteTermKey = const Value.absent(),
    this.calendarId = const Value.absent(),
    this.calendarRevision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SemestersCompanion.insert({
    required String id,
    required String academicYear,
    required int term,
    required String label,
    this.remoteTermKey = const Value.absent(),
    this.calendarId = const Value.absent(),
    this.calendarRevision = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        academicYear = Value(academicYear),
        term = Value(term),
        label = Value(label),
        createdAt = Value(createdAt);
  static Insertable<Semester> custom({
    Expression<String>? id,
    Expression<String>? academicYear,
    Expression<int>? term,
    Expression<String>? label,
    Expression<String>? remoteTermKey,
    Expression<String>? calendarId,
    Expression<int>? calendarRevision,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (academicYear != null) 'academic_year': academicYear,
      if (term != null) 'term': term,
      if (label != null) 'label': label,
      if (remoteTermKey != null) 'remote_term_key': remoteTermKey,
      if (calendarId != null) 'calendar_id': calendarId,
      if (calendarRevision != null) 'calendar_revision': calendarRevision,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SemestersCompanion copyWith(
      {Value<String>? id,
      Value<String>? academicYear,
      Value<int>? term,
      Value<String>? label,
      Value<String?>? remoteTermKey,
      Value<String?>? calendarId,
      Value<int?>? calendarRevision,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return SemestersCompanion(
      id: id ?? this.id,
      academicYear: academicYear ?? this.academicYear,
      term: term ?? this.term,
      label: label ?? this.label,
      remoteTermKey: remoteTermKey ?? this.remoteTermKey,
      calendarId: calendarId ?? this.calendarId,
      calendarRevision: calendarRevision ?? this.calendarRevision,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (academicYear.present) {
      map['academic_year'] = Variable<String>(academicYear.value);
    }
    if (term.present) {
      map['term'] = Variable<int>(term.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (remoteTermKey.present) {
      map['remote_term_key'] = Variable<String>(remoteTermKey.value);
    }
    if (calendarId.present) {
      map['calendar_id'] = Variable<String>(calendarId.value);
    }
    if (calendarRevision.present) {
      map['calendar_revision'] = Variable<int>(calendarRevision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SemestersCompanion(')
          ..write('id: $id, ')
          ..write('academicYear: $academicYear, ')
          ..write('term: $term, ')
          ..write('label: $label, ')
          ..write('remoteTermKey: $remoteTermKey, ')
          ..write('calendarId: $calendarId, ')
          ..write('calendarRevision: $calendarRevision, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CoursesTable extends Courses with TableInfo<$CoursesTable, Course> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoursesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _semesterIdMeta =
      const VerificationMeta('semesterId');
  @override
  late final GeneratedColumn<String> semesterId = GeneratedColumn<String>(
      'semester_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES semesters (id) ON DELETE CASCADE'));
  static const VerificationMeta _sourceTypeMeta =
      const VerificationMeta('sourceType');
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
      'source_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceCourseKeyMeta =
      const VerificationMeta('sourceCourseKey');
  @override
  late final GeneratedColumn<String> sourceCourseKey = GeneratedColumn<String>(
      'source_course_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameKeyMeta =
      const VerificationMeta('nameKey');
  @override
  late final GeneratedColumn<String> nameKey = GeneratedColumn<String>(
      'name_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _teachingClassMeta =
      const VerificationMeta('teachingClass');
  @override
  late final GeneratedColumn<String> teachingClass = GeneratedColumn<String>(
      'teaching_class', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _creditsMeta =
      const VerificationMeta('credits');
  @override
  late final GeneratedColumn<double> credits = GeneratedColumn<double>(
      'credits', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _assessmentMeta =
      const VerificationMeta('assessment');
  @override
  late final GeneratedColumn<String> assessment = GeneratedColumn<String>(
      'assessment', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorOverrideMeta =
      const VerificationMeta('colorOverride');
  @override
  late final GeneratedColumn<int> colorOverride = GeneratedColumn<int>(
      'color_override', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
      'hidden', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("hidden" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        semesterId,
        sourceType,
        sourceCourseKey,
        name,
        nameKey,
        code,
        teachingClass,
        credits,
        assessment,
        note,
        colorOverride,
        hidden,
        deleted,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'courses';
  @override
  VerificationContext validateIntegrity(Insertable<Course> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('semester_id')) {
      context.handle(
          _semesterIdMeta,
          semesterId.isAcceptableOrUnknown(
              data['semester_id']!, _semesterIdMeta));
    } else if (isInserting) {
      context.missing(_semesterIdMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
          _sourceTypeMeta,
          sourceType.isAcceptableOrUnknown(
              data['source_type']!, _sourceTypeMeta));
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('source_course_key')) {
      context.handle(
          _sourceCourseKeyMeta,
          sourceCourseKey.isAcceptableOrUnknown(
              data['source_course_key']!, _sourceCourseKeyMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_key')) {
      context.handle(_nameKeyMeta,
          nameKey.isAcceptableOrUnknown(data['name_key']!, _nameKeyMeta));
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    }
    if (data.containsKey('teaching_class')) {
      context.handle(
          _teachingClassMeta,
          teachingClass.isAcceptableOrUnknown(
              data['teaching_class']!, _teachingClassMeta));
    }
    if (data.containsKey('credits')) {
      context.handle(_creditsMeta,
          credits.isAcceptableOrUnknown(data['credits']!, _creditsMeta));
    }
    if (data.containsKey('assessment')) {
      context.handle(
          _assessmentMeta,
          assessment.isAcceptableOrUnknown(
              data['assessment']!, _assessmentMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('color_override')) {
      context.handle(
          _colorOverrideMeta,
          colorOverride.isAcceptableOrUnknown(
              data['color_override']!, _colorOverrideMeta));
    }
    if (data.containsKey('hidden')) {
      context.handle(_hiddenMeta,
          hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Course map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Course(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      semesterId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}semester_id'])!,
      sourceType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_type'])!,
      sourceCourseKey: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}source_course_key']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      nameKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name_key'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code']),
      teachingClass: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}teaching_class']),
      credits: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}credits']),
      assessment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}assessment']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      colorOverride: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color_override']),
      hidden: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}hidden'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CoursesTable createAlias(String alias) {
    return $CoursesTable(attachedDatabase, alias);
  }
}

class Course extends DataClass implements Insertable<Course> {
  final String id;
  final String semesterId;
  final String sourceType;
  final String? sourceCourseKey;
  final String name;
  final String nameKey;
  final String? code;
  final String? teachingClass;
  final double? credits;
  final String? assessment;
  final String? note;
  final int? colorOverride;
  final bool hidden;
  final bool deleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Course(
      {required this.id,
      required this.semesterId,
      required this.sourceType,
      this.sourceCourseKey,
      required this.name,
      required this.nameKey,
      this.code,
      this.teachingClass,
      this.credits,
      this.assessment,
      this.note,
      this.colorOverride,
      required this.hidden,
      required this.deleted,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['semester_id'] = Variable<String>(semesterId);
    map['source_type'] = Variable<String>(sourceType);
    if (!nullToAbsent || sourceCourseKey != null) {
      map['source_course_key'] = Variable<String>(sourceCourseKey);
    }
    map['name'] = Variable<String>(name);
    map['name_key'] = Variable<String>(nameKey);
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    if (!nullToAbsent || teachingClass != null) {
      map['teaching_class'] = Variable<String>(teachingClass);
    }
    if (!nullToAbsent || credits != null) {
      map['credits'] = Variable<double>(credits);
    }
    if (!nullToAbsent || assessment != null) {
      map['assessment'] = Variable<String>(assessment);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || colorOverride != null) {
      map['color_override'] = Variable<int>(colorOverride);
    }
    map['hidden'] = Variable<bool>(hidden);
    map['deleted'] = Variable<bool>(deleted);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CoursesCompanion toCompanion(bool nullToAbsent) {
    return CoursesCompanion(
      id: Value(id),
      semesterId: Value(semesterId),
      sourceType: Value(sourceType),
      sourceCourseKey: sourceCourseKey == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceCourseKey),
      name: Value(name),
      nameKey: Value(nameKey),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      teachingClass: teachingClass == null && nullToAbsent
          ? const Value.absent()
          : Value(teachingClass),
      credits: credits == null && nullToAbsent
          ? const Value.absent()
          : Value(credits),
      assessment: assessment == null && nullToAbsent
          ? const Value.absent()
          : Value(assessment),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      colorOverride: colorOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(colorOverride),
      hidden: Value(hidden),
      deleted: Value(deleted),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Course.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Course(
      id: serializer.fromJson<String>(json['id']),
      semesterId: serializer.fromJson<String>(json['semesterId']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      sourceCourseKey: serializer.fromJson<String?>(json['sourceCourseKey']),
      name: serializer.fromJson<String>(json['name']),
      nameKey: serializer.fromJson<String>(json['nameKey']),
      code: serializer.fromJson<String?>(json['code']),
      teachingClass: serializer.fromJson<String?>(json['teachingClass']),
      credits: serializer.fromJson<double?>(json['credits']),
      assessment: serializer.fromJson<String?>(json['assessment']),
      note: serializer.fromJson<String?>(json['note']),
      colorOverride: serializer.fromJson<int?>(json['colorOverride']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'semesterId': serializer.toJson<String>(semesterId),
      'sourceType': serializer.toJson<String>(sourceType),
      'sourceCourseKey': serializer.toJson<String?>(sourceCourseKey),
      'name': serializer.toJson<String>(name),
      'nameKey': serializer.toJson<String>(nameKey),
      'code': serializer.toJson<String?>(code),
      'teachingClass': serializer.toJson<String?>(teachingClass),
      'credits': serializer.toJson<double?>(credits),
      'assessment': serializer.toJson<String?>(assessment),
      'note': serializer.toJson<String?>(note),
      'colorOverride': serializer.toJson<int?>(colorOverride),
      'hidden': serializer.toJson<bool>(hidden),
      'deleted': serializer.toJson<bool>(deleted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Course copyWith(
          {String? id,
          String? semesterId,
          String? sourceType,
          Value<String?> sourceCourseKey = const Value.absent(),
          String? name,
          String? nameKey,
          Value<String?> code = const Value.absent(),
          Value<String?> teachingClass = const Value.absent(),
          Value<double?> credits = const Value.absent(),
          Value<String?> assessment = const Value.absent(),
          Value<String?> note = const Value.absent(),
          Value<int?> colorOverride = const Value.absent(),
          bool? hidden,
          bool? deleted,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Course(
        id: id ?? this.id,
        semesterId: semesterId ?? this.semesterId,
        sourceType: sourceType ?? this.sourceType,
        sourceCourseKey: sourceCourseKey.present
            ? sourceCourseKey.value
            : this.sourceCourseKey,
        name: name ?? this.name,
        nameKey: nameKey ?? this.nameKey,
        code: code.present ? code.value : this.code,
        teachingClass:
            teachingClass.present ? teachingClass.value : this.teachingClass,
        credits: credits.present ? credits.value : this.credits,
        assessment: assessment.present ? assessment.value : this.assessment,
        note: note.present ? note.value : this.note,
        colorOverride:
            colorOverride.present ? colorOverride.value : this.colorOverride,
        hidden: hidden ?? this.hidden,
        deleted: deleted ?? this.deleted,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Course copyWithCompanion(CoursesCompanion data) {
    return Course(
      id: data.id.present ? data.id.value : this.id,
      semesterId:
          data.semesterId.present ? data.semesterId.value : this.semesterId,
      sourceType:
          data.sourceType.present ? data.sourceType.value : this.sourceType,
      sourceCourseKey: data.sourceCourseKey.present
          ? data.sourceCourseKey.value
          : this.sourceCourseKey,
      name: data.name.present ? data.name.value : this.name,
      nameKey: data.nameKey.present ? data.nameKey.value : this.nameKey,
      code: data.code.present ? data.code.value : this.code,
      teachingClass: data.teachingClass.present
          ? data.teachingClass.value
          : this.teachingClass,
      credits: data.credits.present ? data.credits.value : this.credits,
      assessment:
          data.assessment.present ? data.assessment.value : this.assessment,
      note: data.note.present ? data.note.value : this.note,
      colorOverride: data.colorOverride.present
          ? data.colorOverride.value
          : this.colorOverride,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Course(')
          ..write('id: $id, ')
          ..write('semesterId: $semesterId, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceCourseKey: $sourceCourseKey, ')
          ..write('name: $name, ')
          ..write('nameKey: $nameKey, ')
          ..write('code: $code, ')
          ..write('teachingClass: $teachingClass, ')
          ..write('credits: $credits, ')
          ..write('assessment: $assessment, ')
          ..write('note: $note, ')
          ..write('colorOverride: $colorOverride, ')
          ..write('hidden: $hidden, ')
          ..write('deleted: $deleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      semesterId,
      sourceType,
      sourceCourseKey,
      name,
      nameKey,
      code,
      teachingClass,
      credits,
      assessment,
      note,
      colorOverride,
      hidden,
      deleted,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Course &&
          other.id == this.id &&
          other.semesterId == this.semesterId &&
          other.sourceType == this.sourceType &&
          other.sourceCourseKey == this.sourceCourseKey &&
          other.name == this.name &&
          other.nameKey == this.nameKey &&
          other.code == this.code &&
          other.teachingClass == this.teachingClass &&
          other.credits == this.credits &&
          other.assessment == this.assessment &&
          other.note == this.note &&
          other.colorOverride == this.colorOverride &&
          other.hidden == this.hidden &&
          other.deleted == this.deleted &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CoursesCompanion extends UpdateCompanion<Course> {
  final Value<String> id;
  final Value<String> semesterId;
  final Value<String> sourceType;
  final Value<String?> sourceCourseKey;
  final Value<String> name;
  final Value<String> nameKey;
  final Value<String?> code;
  final Value<String?> teachingClass;
  final Value<double?> credits;
  final Value<String?> assessment;
  final Value<String?> note;
  final Value<int?> colorOverride;
  final Value<bool> hidden;
  final Value<bool> deleted;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CoursesCompanion({
    this.id = const Value.absent(),
    this.semesterId = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceCourseKey = const Value.absent(),
    this.name = const Value.absent(),
    this.nameKey = const Value.absent(),
    this.code = const Value.absent(),
    this.teachingClass = const Value.absent(),
    this.credits = const Value.absent(),
    this.assessment = const Value.absent(),
    this.note = const Value.absent(),
    this.colorOverride = const Value.absent(),
    this.hidden = const Value.absent(),
    this.deleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CoursesCompanion.insert({
    required String id,
    required String semesterId,
    required String sourceType,
    this.sourceCourseKey = const Value.absent(),
    required String name,
    this.nameKey = const Value.absent(),
    this.code = const Value.absent(),
    this.teachingClass = const Value.absent(),
    this.credits = const Value.absent(),
    this.assessment = const Value.absent(),
    this.note = const Value.absent(),
    this.colorOverride = const Value.absent(),
    this.hidden = const Value.absent(),
    this.deleted = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        semesterId = Value(semesterId),
        sourceType = Value(sourceType),
        name = Value(name),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Course> custom({
    Expression<String>? id,
    Expression<String>? semesterId,
    Expression<String>? sourceType,
    Expression<String>? sourceCourseKey,
    Expression<String>? name,
    Expression<String>? nameKey,
    Expression<String>? code,
    Expression<String>? teachingClass,
    Expression<double>? credits,
    Expression<String>? assessment,
    Expression<String>? note,
    Expression<int>? colorOverride,
    Expression<bool>? hidden,
    Expression<bool>? deleted,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (semesterId != null) 'semester_id': semesterId,
      if (sourceType != null) 'source_type': sourceType,
      if (sourceCourseKey != null) 'source_course_key': sourceCourseKey,
      if (name != null) 'name': name,
      if (nameKey != null) 'name_key': nameKey,
      if (code != null) 'code': code,
      if (teachingClass != null) 'teaching_class': teachingClass,
      if (credits != null) 'credits': credits,
      if (assessment != null) 'assessment': assessment,
      if (note != null) 'note': note,
      if (colorOverride != null) 'color_override': colorOverride,
      if (hidden != null) 'hidden': hidden,
      if (deleted != null) 'deleted': deleted,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CoursesCompanion copyWith(
      {Value<String>? id,
      Value<String>? semesterId,
      Value<String>? sourceType,
      Value<String?>? sourceCourseKey,
      Value<String>? name,
      Value<String>? nameKey,
      Value<String?>? code,
      Value<String?>? teachingClass,
      Value<double?>? credits,
      Value<String?>? assessment,
      Value<String?>? note,
      Value<int?>? colorOverride,
      Value<bool>? hidden,
      Value<bool>? deleted,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return CoursesCompanion(
      id: id ?? this.id,
      semesterId: semesterId ?? this.semesterId,
      sourceType: sourceType ?? this.sourceType,
      sourceCourseKey: sourceCourseKey ?? this.sourceCourseKey,
      name: name ?? this.name,
      nameKey: nameKey ?? this.nameKey,
      code: code ?? this.code,
      teachingClass: teachingClass ?? this.teachingClass,
      credits: credits ?? this.credits,
      assessment: assessment ?? this.assessment,
      note: note ?? this.note,
      colorOverride: colorOverride ?? this.colorOverride,
      hidden: hidden ?? this.hidden,
      deleted: deleted ?? this.deleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (semesterId.present) {
      map['semester_id'] = Variable<String>(semesterId.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (sourceCourseKey.present) {
      map['source_course_key'] = Variable<String>(sourceCourseKey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameKey.present) {
      map['name_key'] = Variable<String>(nameKey.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (teachingClass.present) {
      map['teaching_class'] = Variable<String>(teachingClass.value);
    }
    if (credits.present) {
      map['credits'] = Variable<double>(credits.value);
    }
    if (assessment.present) {
      map['assessment'] = Variable<String>(assessment.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (colorOverride.present) {
      map['color_override'] = Variable<int>(colorOverride.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoursesCompanion(')
          ..write('id: $id, ')
          ..write('semesterId: $semesterId, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceCourseKey: $sourceCourseKey, ')
          ..write('name: $name, ')
          ..write('nameKey: $nameKey, ')
          ..write('code: $code, ')
          ..write('teachingClass: $teachingClass, ')
          ..write('credits: $credits, ')
          ..write('assessment: $assessment, ')
          ..write('note: $note, ')
          ..write('colorOverride: $colorOverride, ')
          ..write('hidden: $hidden, ')
          ..write('deleted: $deleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MeetingRulesTable extends MeetingRules
    with TableInfo<$MeetingRulesTable, StoredMeetingRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeetingRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _courseIdMeta =
      const VerificationMeta('courseId');
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
      'course_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES courses (id) ON DELETE CASCADE'));
  static const VerificationMeta _sourceMeetingKeyMeta =
      const VerificationMeta('sourceMeetingKey');
  @override
  late final GeneratedColumn<String> sourceMeetingKey = GeneratedColumn<String>(
      'source_meeting_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _weekdayMeta =
      const VerificationMeta('weekday');
  @override
  late final GeneratedColumn<int> weekday = GeneratedColumn<int>(
      'weekday', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _startSectionMeta =
      const VerificationMeta('startSection');
  @override
  late final GeneratedColumn<int> startSection = GeneratedColumn<int>(
      'start_section', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _endSectionMeta =
      const VerificationMeta('endSection');
  @override
  late final GeneratedColumn<int> endSection = GeneratedColumn<int>(
      'end_section', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _teacherMeta =
      const VerificationMeta('teacher');
  @override
  late final GeneratedColumn<String> teacher = GeneratedColumn<String>(
      'teacher', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _campusMeta = const VerificationMeta('campus');
  @override
  late final GeneratedColumn<String> campus = GeneratedColumn<String>(
      'campus', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _roomMeta = const VerificationMeta('room');
  @override
  late final GeneratedColumn<String> room = GeneratedColumn<String>(
      'room', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _weekMaskMeta =
      const VerificationMeta('weekMask');
  @override
  late final GeneratedColumn<int> weekMask = GeneratedColumn<int>(
      'week_mask', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _rawWeekTextMeta =
      const VerificationMeta('rawWeekText');
  @override
  late final GeneratedColumn<String> rawWeekText = GeneratedColumn<String>(
      'raw_week_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        courseId,
        sourceMeetingKey,
        weekday,
        startSection,
        endSection,
        teacher,
        campus,
        room,
        weekMask,
        rawWeekText
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meeting_rules';
  @override
  VerificationContext validateIntegrity(Insertable<StoredMeetingRule> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(_courseIdMeta,
          courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta));
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('source_meeting_key')) {
      context.handle(
          _sourceMeetingKeyMeta,
          sourceMeetingKey.isAcceptableOrUnknown(
              data['source_meeting_key']!, _sourceMeetingKeyMeta));
    }
    if (data.containsKey('weekday')) {
      context.handle(_weekdayMeta,
          weekday.isAcceptableOrUnknown(data['weekday']!, _weekdayMeta));
    } else if (isInserting) {
      context.missing(_weekdayMeta);
    }
    if (data.containsKey('start_section')) {
      context.handle(
          _startSectionMeta,
          startSection.isAcceptableOrUnknown(
              data['start_section']!, _startSectionMeta));
    } else if (isInserting) {
      context.missing(_startSectionMeta);
    }
    if (data.containsKey('end_section')) {
      context.handle(
          _endSectionMeta,
          endSection.isAcceptableOrUnknown(
              data['end_section']!, _endSectionMeta));
    } else if (isInserting) {
      context.missing(_endSectionMeta);
    }
    if (data.containsKey('teacher')) {
      context.handle(_teacherMeta,
          teacher.isAcceptableOrUnknown(data['teacher']!, _teacherMeta));
    }
    if (data.containsKey('campus')) {
      context.handle(_campusMeta,
          campus.isAcceptableOrUnknown(data['campus']!, _campusMeta));
    }
    if (data.containsKey('room')) {
      context.handle(
          _roomMeta, room.isAcceptableOrUnknown(data['room']!, _roomMeta));
    }
    if (data.containsKey('week_mask')) {
      context.handle(_weekMaskMeta,
          weekMask.isAcceptableOrUnknown(data['week_mask']!, _weekMaskMeta));
    } else if (isInserting) {
      context.missing(_weekMaskMeta);
    }
    if (data.containsKey('raw_week_text')) {
      context.handle(
          _rawWeekTextMeta,
          rawWeekText.isAcceptableOrUnknown(
              data['raw_week_text']!, _rawWeekTextMeta));
    } else if (isInserting) {
      context.missing(_rawWeekTextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredMeetingRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredMeetingRule(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      courseId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course_id'])!,
      sourceMeetingKey: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}source_meeting_key']),
      weekday: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}weekday'])!,
      startSection: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}start_section'])!,
      endSection: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}end_section'])!,
      teacher: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}teacher']),
      campus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}campus']),
      room: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}room']),
      weekMask: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}week_mask'])!,
      rawWeekText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw_week_text'])!,
    );
  }

  @override
  $MeetingRulesTable createAlias(String alias) {
    return $MeetingRulesTable(attachedDatabase, alias);
  }
}

class StoredMeetingRule extends DataClass
    implements Insertable<StoredMeetingRule> {
  final String id;
  final String courseId;
  final String? sourceMeetingKey;
  final int weekday;
  final int startSection;
  final int endSection;
  final String? teacher;
  final String? campus;
  final String? room;
  final int weekMask;
  final String rawWeekText;
  const StoredMeetingRule(
      {required this.id,
      required this.courseId,
      this.sourceMeetingKey,
      required this.weekday,
      required this.startSection,
      required this.endSection,
      this.teacher,
      this.campus,
      this.room,
      required this.weekMask,
      required this.rawWeekText});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['course_id'] = Variable<String>(courseId);
    if (!nullToAbsent || sourceMeetingKey != null) {
      map['source_meeting_key'] = Variable<String>(sourceMeetingKey);
    }
    map['weekday'] = Variable<int>(weekday);
    map['start_section'] = Variable<int>(startSection);
    map['end_section'] = Variable<int>(endSection);
    if (!nullToAbsent || teacher != null) {
      map['teacher'] = Variable<String>(teacher);
    }
    if (!nullToAbsent || campus != null) {
      map['campus'] = Variable<String>(campus);
    }
    if (!nullToAbsent || room != null) {
      map['room'] = Variable<String>(room);
    }
    map['week_mask'] = Variable<int>(weekMask);
    map['raw_week_text'] = Variable<String>(rawWeekText);
    return map;
  }

  MeetingRulesCompanion toCompanion(bool nullToAbsent) {
    return MeetingRulesCompanion(
      id: Value(id),
      courseId: Value(courseId),
      sourceMeetingKey: sourceMeetingKey == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceMeetingKey),
      weekday: Value(weekday),
      startSection: Value(startSection),
      endSection: Value(endSection),
      teacher: teacher == null && nullToAbsent
          ? const Value.absent()
          : Value(teacher),
      campus:
          campus == null && nullToAbsent ? const Value.absent() : Value(campus),
      room: room == null && nullToAbsent ? const Value.absent() : Value(room),
      weekMask: Value(weekMask),
      rawWeekText: Value(rawWeekText),
    );
  }

  factory StoredMeetingRule.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredMeetingRule(
      id: serializer.fromJson<String>(json['id']),
      courseId: serializer.fromJson<String>(json['courseId']),
      sourceMeetingKey: serializer.fromJson<String?>(json['sourceMeetingKey']),
      weekday: serializer.fromJson<int>(json['weekday']),
      startSection: serializer.fromJson<int>(json['startSection']),
      endSection: serializer.fromJson<int>(json['endSection']),
      teacher: serializer.fromJson<String?>(json['teacher']),
      campus: serializer.fromJson<String?>(json['campus']),
      room: serializer.fromJson<String?>(json['room']),
      weekMask: serializer.fromJson<int>(json['weekMask']),
      rawWeekText: serializer.fromJson<String>(json['rawWeekText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'courseId': serializer.toJson<String>(courseId),
      'sourceMeetingKey': serializer.toJson<String?>(sourceMeetingKey),
      'weekday': serializer.toJson<int>(weekday),
      'startSection': serializer.toJson<int>(startSection),
      'endSection': serializer.toJson<int>(endSection),
      'teacher': serializer.toJson<String?>(teacher),
      'campus': serializer.toJson<String?>(campus),
      'room': serializer.toJson<String?>(room),
      'weekMask': serializer.toJson<int>(weekMask),
      'rawWeekText': serializer.toJson<String>(rawWeekText),
    };
  }

  StoredMeetingRule copyWith(
          {String? id,
          String? courseId,
          Value<String?> sourceMeetingKey = const Value.absent(),
          int? weekday,
          int? startSection,
          int? endSection,
          Value<String?> teacher = const Value.absent(),
          Value<String?> campus = const Value.absent(),
          Value<String?> room = const Value.absent(),
          int? weekMask,
          String? rawWeekText}) =>
      StoredMeetingRule(
        id: id ?? this.id,
        courseId: courseId ?? this.courseId,
        sourceMeetingKey: sourceMeetingKey.present
            ? sourceMeetingKey.value
            : this.sourceMeetingKey,
        weekday: weekday ?? this.weekday,
        startSection: startSection ?? this.startSection,
        endSection: endSection ?? this.endSection,
        teacher: teacher.present ? teacher.value : this.teacher,
        campus: campus.present ? campus.value : this.campus,
        room: room.present ? room.value : this.room,
        weekMask: weekMask ?? this.weekMask,
        rawWeekText: rawWeekText ?? this.rawWeekText,
      );
  StoredMeetingRule copyWithCompanion(MeetingRulesCompanion data) {
    return StoredMeetingRule(
      id: data.id.present ? data.id.value : this.id,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      sourceMeetingKey: data.sourceMeetingKey.present
          ? data.sourceMeetingKey.value
          : this.sourceMeetingKey,
      weekday: data.weekday.present ? data.weekday.value : this.weekday,
      startSection: data.startSection.present
          ? data.startSection.value
          : this.startSection,
      endSection:
          data.endSection.present ? data.endSection.value : this.endSection,
      teacher: data.teacher.present ? data.teacher.value : this.teacher,
      campus: data.campus.present ? data.campus.value : this.campus,
      room: data.room.present ? data.room.value : this.room,
      weekMask: data.weekMask.present ? data.weekMask.value : this.weekMask,
      rawWeekText:
          data.rawWeekText.present ? data.rawWeekText.value : this.rawWeekText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredMeetingRule(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('sourceMeetingKey: $sourceMeetingKey, ')
          ..write('weekday: $weekday, ')
          ..write('startSection: $startSection, ')
          ..write('endSection: $endSection, ')
          ..write('teacher: $teacher, ')
          ..write('campus: $campus, ')
          ..write('room: $room, ')
          ..write('weekMask: $weekMask, ')
          ..write('rawWeekText: $rawWeekText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, courseId, sourceMeetingKey, weekday,
      startSection, endSection, teacher, campus, room, weekMask, rawWeekText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredMeetingRule &&
          other.id == this.id &&
          other.courseId == this.courseId &&
          other.sourceMeetingKey == this.sourceMeetingKey &&
          other.weekday == this.weekday &&
          other.startSection == this.startSection &&
          other.endSection == this.endSection &&
          other.teacher == this.teacher &&
          other.campus == this.campus &&
          other.room == this.room &&
          other.weekMask == this.weekMask &&
          other.rawWeekText == this.rawWeekText);
}

class MeetingRulesCompanion extends UpdateCompanion<StoredMeetingRule> {
  final Value<String> id;
  final Value<String> courseId;
  final Value<String?> sourceMeetingKey;
  final Value<int> weekday;
  final Value<int> startSection;
  final Value<int> endSection;
  final Value<String?> teacher;
  final Value<String?> campus;
  final Value<String?> room;
  final Value<int> weekMask;
  final Value<String> rawWeekText;
  final Value<int> rowid;
  const MeetingRulesCompanion({
    this.id = const Value.absent(),
    this.courseId = const Value.absent(),
    this.sourceMeetingKey = const Value.absent(),
    this.weekday = const Value.absent(),
    this.startSection = const Value.absent(),
    this.endSection = const Value.absent(),
    this.teacher = const Value.absent(),
    this.campus = const Value.absent(),
    this.room = const Value.absent(),
    this.weekMask = const Value.absent(),
    this.rawWeekText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MeetingRulesCompanion.insert({
    required String id,
    required String courseId,
    this.sourceMeetingKey = const Value.absent(),
    required int weekday,
    required int startSection,
    required int endSection,
    this.teacher = const Value.absent(),
    this.campus = const Value.absent(),
    this.room = const Value.absent(),
    required int weekMask,
    required String rawWeekText,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        courseId = Value(courseId),
        weekday = Value(weekday),
        startSection = Value(startSection),
        endSection = Value(endSection),
        weekMask = Value(weekMask),
        rawWeekText = Value(rawWeekText);
  static Insertable<StoredMeetingRule> custom({
    Expression<String>? id,
    Expression<String>? courseId,
    Expression<String>? sourceMeetingKey,
    Expression<int>? weekday,
    Expression<int>? startSection,
    Expression<int>? endSection,
    Expression<String>? teacher,
    Expression<String>? campus,
    Expression<String>? room,
    Expression<int>? weekMask,
    Expression<String>? rawWeekText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courseId != null) 'course_id': courseId,
      if (sourceMeetingKey != null) 'source_meeting_key': sourceMeetingKey,
      if (weekday != null) 'weekday': weekday,
      if (startSection != null) 'start_section': startSection,
      if (endSection != null) 'end_section': endSection,
      if (teacher != null) 'teacher': teacher,
      if (campus != null) 'campus': campus,
      if (room != null) 'room': room,
      if (weekMask != null) 'week_mask': weekMask,
      if (rawWeekText != null) 'raw_week_text': rawWeekText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MeetingRulesCompanion copyWith(
      {Value<String>? id,
      Value<String>? courseId,
      Value<String?>? sourceMeetingKey,
      Value<int>? weekday,
      Value<int>? startSection,
      Value<int>? endSection,
      Value<String?>? teacher,
      Value<String?>? campus,
      Value<String?>? room,
      Value<int>? weekMask,
      Value<String>? rawWeekText,
      Value<int>? rowid}) {
    return MeetingRulesCompanion(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      sourceMeetingKey: sourceMeetingKey ?? this.sourceMeetingKey,
      weekday: weekday ?? this.weekday,
      startSection: startSection ?? this.startSection,
      endSection: endSection ?? this.endSection,
      teacher: teacher ?? this.teacher,
      campus: campus ?? this.campus,
      room: room ?? this.room,
      weekMask: weekMask ?? this.weekMask,
      rawWeekText: rawWeekText ?? this.rawWeekText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (sourceMeetingKey.present) {
      map['source_meeting_key'] = Variable<String>(sourceMeetingKey.value);
    }
    if (weekday.present) {
      map['weekday'] = Variable<int>(weekday.value);
    }
    if (startSection.present) {
      map['start_section'] = Variable<int>(startSection.value);
    }
    if (endSection.present) {
      map['end_section'] = Variable<int>(endSection.value);
    }
    if (teacher.present) {
      map['teacher'] = Variable<String>(teacher.value);
    }
    if (campus.present) {
      map['campus'] = Variable<String>(campus.value);
    }
    if (room.present) {
      map['room'] = Variable<String>(room.value);
    }
    if (weekMask.present) {
      map['week_mask'] = Variable<int>(weekMask.value);
    }
    if (rawWeekText.present) {
      map['raw_week_text'] = Variable<String>(rawWeekText.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeetingRulesCompanion(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('sourceMeetingKey: $sourceMeetingKey, ')
          ..write('weekday: $weekday, ')
          ..write('startSection: $startSection, ')
          ..write('endSection: $endSection, ')
          ..write('teacher: $teacher, ')
          ..write('campus: $campus, ')
          ..write('room: $room, ')
          ..write('weekMask: $weekMask, ')
          ..write('rawWeekText: $rawWeekText, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CourseExceptionsTable extends CourseExceptions
    with TableInfo<$CourseExceptionsTable, CourseException> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CourseExceptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _semesterIdMeta =
      const VerificationMeta('semesterId');
  @override
  late final GeneratedColumn<String> semesterId = GeneratedColumn<String>(
      'semester_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES semesters (id) ON DELETE CASCADE'));
  static const VerificationMeta _courseIdMeta =
      const VerificationMeta('courseId');
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
      'course_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeetingIdMeta =
      const VerificationMeta('sourceMeetingId');
  @override
  late final GeneratedColumn<String> sourceMeetingId = GeneratedColumn<String>(
      'source_meeting_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceDateMeta =
      const VerificationMeta('sourceDate');
  @override
  late final GeneratedColumn<DateTime> sourceDate = GeneratedColumn<DateTime>(
      'source_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetDateMeta =
      const VerificationMeta('targetDate');
  @override
  late final GeneratedColumn<DateTime> targetDate = GeneratedColumn<DateTime>(
      'target_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _targetStartSectionMeta =
      const VerificationMeta('targetStartSection');
  @override
  late final GeneratedColumn<int> targetStartSection = GeneratedColumn<int>(
      'target_start_section', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _targetEndSectionMeta =
      const VerificationMeta('targetEndSection');
  @override
  late final GeneratedColumn<int> targetEndSection = GeneratedColumn<int>(
      'target_end_section', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _teacherOverrideMeta =
      const VerificationMeta('teacherOverride');
  @override
  late final GeneratedColumn<String> teacherOverride = GeneratedColumn<String>(
      'teacher_override', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _campusOverrideMeta =
      const VerificationMeta('campusOverride');
  @override
  late final GeneratedColumn<String> campusOverride = GeneratedColumn<String>(
      'campus_override', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _roomOverrideMeta =
      const VerificationMeta('roomOverride');
  @override
  late final GeneratedColumn<String> roomOverride = GeneratedColumn<String>(
      'room_override', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _addedCourseNameMeta =
      const VerificationMeta('addedCourseName');
  @override
  late final GeneratedColumn<String> addedCourseName = GeneratedColumn<String>(
      'added_course_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        semesterId,
        courseId,
        sourceMeetingId,
        sourceDate,
        type,
        targetDate,
        targetStartSection,
        targetEndSection,
        teacherOverride,
        campusOverride,
        roomOverride,
        addedCourseName,
        note,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'course_exceptions';
  @override
  VerificationContext validateIntegrity(Insertable<CourseException> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('semester_id')) {
      context.handle(
          _semesterIdMeta,
          semesterId.isAcceptableOrUnknown(
              data['semester_id']!, _semesterIdMeta));
    } else if (isInserting) {
      context.missing(_semesterIdMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(_courseIdMeta,
          courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta));
    }
    if (data.containsKey('source_meeting_id')) {
      context.handle(
          _sourceMeetingIdMeta,
          sourceMeetingId.isAcceptableOrUnknown(
              data['source_meeting_id']!, _sourceMeetingIdMeta));
    }
    if (data.containsKey('source_date')) {
      context.handle(
          _sourceDateMeta,
          sourceDate.isAcceptableOrUnknown(
              data['source_date']!, _sourceDateMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('target_date')) {
      context.handle(
          _targetDateMeta,
          targetDate.isAcceptableOrUnknown(
              data['target_date']!, _targetDateMeta));
    }
    if (data.containsKey('target_start_section')) {
      context.handle(
          _targetStartSectionMeta,
          targetStartSection.isAcceptableOrUnknown(
              data['target_start_section']!, _targetStartSectionMeta));
    }
    if (data.containsKey('target_end_section')) {
      context.handle(
          _targetEndSectionMeta,
          targetEndSection.isAcceptableOrUnknown(
              data['target_end_section']!, _targetEndSectionMeta));
    }
    if (data.containsKey('teacher_override')) {
      context.handle(
          _teacherOverrideMeta,
          teacherOverride.isAcceptableOrUnknown(
              data['teacher_override']!, _teacherOverrideMeta));
    }
    if (data.containsKey('campus_override')) {
      context.handle(
          _campusOverrideMeta,
          campusOverride.isAcceptableOrUnknown(
              data['campus_override']!, _campusOverrideMeta));
    }
    if (data.containsKey('room_override')) {
      context.handle(
          _roomOverrideMeta,
          roomOverride.isAcceptableOrUnknown(
              data['room_override']!, _roomOverrideMeta));
    }
    if (data.containsKey('added_course_name')) {
      context.handle(
          _addedCourseNameMeta,
          addedCourseName.isAcceptableOrUnknown(
              data['added_course_name']!, _addedCourseNameMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CourseException map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CourseException(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      semesterId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}semester_id'])!,
      courseId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course_id']),
      sourceMeetingId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}source_meeting_id']),
      sourceDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}source_date']),
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      targetDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}target_date']),
      targetStartSection: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}target_start_section']),
      targetEndSection: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}target_end_section']),
      teacherOverride: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}teacher_override']),
      campusOverride: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}campus_override']),
      roomOverride: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}room_override']),
      addedCourseName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}added_course_name']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $CourseExceptionsTable createAlias(String alias) {
    return $CourseExceptionsTable(attachedDatabase, alias);
  }
}

class CourseException extends DataClass implements Insertable<CourseException> {
  final String id;
  final String semesterId;
  final String? courseId;
  final String? sourceMeetingId;
  final DateTime? sourceDate;
  final String type;
  final DateTime? targetDate;
  final int? targetStartSection;
  final int? targetEndSection;
  final String? teacherOverride;
  final String? campusOverride;
  final String? roomOverride;
  final String? addedCourseName;
  final String? note;
  final DateTime createdAt;
  const CourseException(
      {required this.id,
      required this.semesterId,
      this.courseId,
      this.sourceMeetingId,
      this.sourceDate,
      required this.type,
      this.targetDate,
      this.targetStartSection,
      this.targetEndSection,
      this.teacherOverride,
      this.campusOverride,
      this.roomOverride,
      this.addedCourseName,
      this.note,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['semester_id'] = Variable<String>(semesterId);
    if (!nullToAbsent || courseId != null) {
      map['course_id'] = Variable<String>(courseId);
    }
    if (!nullToAbsent || sourceMeetingId != null) {
      map['source_meeting_id'] = Variable<String>(sourceMeetingId);
    }
    if (!nullToAbsent || sourceDate != null) {
      map['source_date'] = Variable<DateTime>(sourceDate);
    }
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || targetDate != null) {
      map['target_date'] = Variable<DateTime>(targetDate);
    }
    if (!nullToAbsent || targetStartSection != null) {
      map['target_start_section'] = Variable<int>(targetStartSection);
    }
    if (!nullToAbsent || targetEndSection != null) {
      map['target_end_section'] = Variable<int>(targetEndSection);
    }
    if (!nullToAbsent || teacherOverride != null) {
      map['teacher_override'] = Variable<String>(teacherOverride);
    }
    if (!nullToAbsent || campusOverride != null) {
      map['campus_override'] = Variable<String>(campusOverride);
    }
    if (!nullToAbsent || roomOverride != null) {
      map['room_override'] = Variable<String>(roomOverride);
    }
    if (!nullToAbsent || addedCourseName != null) {
      map['added_course_name'] = Variable<String>(addedCourseName);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CourseExceptionsCompanion toCompanion(bool nullToAbsent) {
    return CourseExceptionsCompanion(
      id: Value(id),
      semesterId: Value(semesterId),
      courseId: courseId == null && nullToAbsent
          ? const Value.absent()
          : Value(courseId),
      sourceMeetingId: sourceMeetingId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceMeetingId),
      sourceDate: sourceDate == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceDate),
      type: Value(type),
      targetDate: targetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDate),
      targetStartSection: targetStartSection == null && nullToAbsent
          ? const Value.absent()
          : Value(targetStartSection),
      targetEndSection: targetEndSection == null && nullToAbsent
          ? const Value.absent()
          : Value(targetEndSection),
      teacherOverride: teacherOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(teacherOverride),
      campusOverride: campusOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(campusOverride),
      roomOverride: roomOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(roomOverride),
      addedCourseName: addedCourseName == null && nullToAbsent
          ? const Value.absent()
          : Value(addedCourseName),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory CourseException.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CourseException(
      id: serializer.fromJson<String>(json['id']),
      semesterId: serializer.fromJson<String>(json['semesterId']),
      courseId: serializer.fromJson<String?>(json['courseId']),
      sourceMeetingId: serializer.fromJson<String?>(json['sourceMeetingId']),
      sourceDate: serializer.fromJson<DateTime?>(json['sourceDate']),
      type: serializer.fromJson<String>(json['type']),
      targetDate: serializer.fromJson<DateTime?>(json['targetDate']),
      targetStartSection: serializer.fromJson<int?>(json['targetStartSection']),
      targetEndSection: serializer.fromJson<int?>(json['targetEndSection']),
      teacherOverride: serializer.fromJson<String?>(json['teacherOverride']),
      campusOverride: serializer.fromJson<String?>(json['campusOverride']),
      roomOverride: serializer.fromJson<String?>(json['roomOverride']),
      addedCourseName: serializer.fromJson<String?>(json['addedCourseName']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'semesterId': serializer.toJson<String>(semesterId),
      'courseId': serializer.toJson<String?>(courseId),
      'sourceMeetingId': serializer.toJson<String?>(sourceMeetingId),
      'sourceDate': serializer.toJson<DateTime?>(sourceDate),
      'type': serializer.toJson<String>(type),
      'targetDate': serializer.toJson<DateTime?>(targetDate),
      'targetStartSection': serializer.toJson<int?>(targetStartSection),
      'targetEndSection': serializer.toJson<int?>(targetEndSection),
      'teacherOverride': serializer.toJson<String?>(teacherOverride),
      'campusOverride': serializer.toJson<String?>(campusOverride),
      'roomOverride': serializer.toJson<String?>(roomOverride),
      'addedCourseName': serializer.toJson<String?>(addedCourseName),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CourseException copyWith(
          {String? id,
          String? semesterId,
          Value<String?> courseId = const Value.absent(),
          Value<String?> sourceMeetingId = const Value.absent(),
          Value<DateTime?> sourceDate = const Value.absent(),
          String? type,
          Value<DateTime?> targetDate = const Value.absent(),
          Value<int?> targetStartSection = const Value.absent(),
          Value<int?> targetEndSection = const Value.absent(),
          Value<String?> teacherOverride = const Value.absent(),
          Value<String?> campusOverride = const Value.absent(),
          Value<String?> roomOverride = const Value.absent(),
          Value<String?> addedCourseName = const Value.absent(),
          Value<String?> note = const Value.absent(),
          DateTime? createdAt}) =>
      CourseException(
        id: id ?? this.id,
        semesterId: semesterId ?? this.semesterId,
        courseId: courseId.present ? courseId.value : this.courseId,
        sourceMeetingId: sourceMeetingId.present
            ? sourceMeetingId.value
            : this.sourceMeetingId,
        sourceDate: sourceDate.present ? sourceDate.value : this.sourceDate,
        type: type ?? this.type,
        targetDate: targetDate.present ? targetDate.value : this.targetDate,
        targetStartSection: targetStartSection.present
            ? targetStartSection.value
            : this.targetStartSection,
        targetEndSection: targetEndSection.present
            ? targetEndSection.value
            : this.targetEndSection,
        teacherOverride: teacherOverride.present
            ? teacherOverride.value
            : this.teacherOverride,
        campusOverride:
            campusOverride.present ? campusOverride.value : this.campusOverride,
        roomOverride:
            roomOverride.present ? roomOverride.value : this.roomOverride,
        addedCourseName: addedCourseName.present
            ? addedCourseName.value
            : this.addedCourseName,
        note: note.present ? note.value : this.note,
        createdAt: createdAt ?? this.createdAt,
      );
  CourseException copyWithCompanion(CourseExceptionsCompanion data) {
    return CourseException(
      id: data.id.present ? data.id.value : this.id,
      semesterId:
          data.semesterId.present ? data.semesterId.value : this.semesterId,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      sourceMeetingId: data.sourceMeetingId.present
          ? data.sourceMeetingId.value
          : this.sourceMeetingId,
      sourceDate:
          data.sourceDate.present ? data.sourceDate.value : this.sourceDate,
      type: data.type.present ? data.type.value : this.type,
      targetDate:
          data.targetDate.present ? data.targetDate.value : this.targetDate,
      targetStartSection: data.targetStartSection.present
          ? data.targetStartSection.value
          : this.targetStartSection,
      targetEndSection: data.targetEndSection.present
          ? data.targetEndSection.value
          : this.targetEndSection,
      teacherOverride: data.teacherOverride.present
          ? data.teacherOverride.value
          : this.teacherOverride,
      campusOverride: data.campusOverride.present
          ? data.campusOverride.value
          : this.campusOverride,
      roomOverride: data.roomOverride.present
          ? data.roomOverride.value
          : this.roomOverride,
      addedCourseName: data.addedCourseName.present
          ? data.addedCourseName.value
          : this.addedCourseName,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CourseException(')
          ..write('id: $id, ')
          ..write('semesterId: $semesterId, ')
          ..write('courseId: $courseId, ')
          ..write('sourceMeetingId: $sourceMeetingId, ')
          ..write('sourceDate: $sourceDate, ')
          ..write('type: $type, ')
          ..write('targetDate: $targetDate, ')
          ..write('targetStartSection: $targetStartSection, ')
          ..write('targetEndSection: $targetEndSection, ')
          ..write('teacherOverride: $teacherOverride, ')
          ..write('campusOverride: $campusOverride, ')
          ..write('roomOverride: $roomOverride, ')
          ..write('addedCourseName: $addedCourseName, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      semesterId,
      courseId,
      sourceMeetingId,
      sourceDate,
      type,
      targetDate,
      targetStartSection,
      targetEndSection,
      teacherOverride,
      campusOverride,
      roomOverride,
      addedCourseName,
      note,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CourseException &&
          other.id == this.id &&
          other.semesterId == this.semesterId &&
          other.courseId == this.courseId &&
          other.sourceMeetingId == this.sourceMeetingId &&
          other.sourceDate == this.sourceDate &&
          other.type == this.type &&
          other.targetDate == this.targetDate &&
          other.targetStartSection == this.targetStartSection &&
          other.targetEndSection == this.targetEndSection &&
          other.teacherOverride == this.teacherOverride &&
          other.campusOverride == this.campusOverride &&
          other.roomOverride == this.roomOverride &&
          other.addedCourseName == this.addedCourseName &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class CourseExceptionsCompanion extends UpdateCompanion<CourseException> {
  final Value<String> id;
  final Value<String> semesterId;
  final Value<String?> courseId;
  final Value<String?> sourceMeetingId;
  final Value<DateTime?> sourceDate;
  final Value<String> type;
  final Value<DateTime?> targetDate;
  final Value<int?> targetStartSection;
  final Value<int?> targetEndSection;
  final Value<String?> teacherOverride;
  final Value<String?> campusOverride;
  final Value<String?> roomOverride;
  final Value<String?> addedCourseName;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CourseExceptionsCompanion({
    this.id = const Value.absent(),
    this.semesterId = const Value.absent(),
    this.courseId = const Value.absent(),
    this.sourceMeetingId = const Value.absent(),
    this.sourceDate = const Value.absent(),
    this.type = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.targetStartSection = const Value.absent(),
    this.targetEndSection = const Value.absent(),
    this.teacherOverride = const Value.absent(),
    this.campusOverride = const Value.absent(),
    this.roomOverride = const Value.absent(),
    this.addedCourseName = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CourseExceptionsCompanion.insert({
    required String id,
    required String semesterId,
    this.courseId = const Value.absent(),
    this.sourceMeetingId = const Value.absent(),
    this.sourceDate = const Value.absent(),
    required String type,
    this.targetDate = const Value.absent(),
    this.targetStartSection = const Value.absent(),
    this.targetEndSection = const Value.absent(),
    this.teacherOverride = const Value.absent(),
    this.campusOverride = const Value.absent(),
    this.roomOverride = const Value.absent(),
    this.addedCourseName = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        semesterId = Value(semesterId),
        type = Value(type),
        createdAt = Value(createdAt);
  static Insertable<CourseException> custom({
    Expression<String>? id,
    Expression<String>? semesterId,
    Expression<String>? courseId,
    Expression<String>? sourceMeetingId,
    Expression<DateTime>? sourceDate,
    Expression<String>? type,
    Expression<DateTime>? targetDate,
    Expression<int>? targetStartSection,
    Expression<int>? targetEndSection,
    Expression<String>? teacherOverride,
    Expression<String>? campusOverride,
    Expression<String>? roomOverride,
    Expression<String>? addedCourseName,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (semesterId != null) 'semester_id': semesterId,
      if (courseId != null) 'course_id': courseId,
      if (sourceMeetingId != null) 'source_meeting_id': sourceMeetingId,
      if (sourceDate != null) 'source_date': sourceDate,
      if (type != null) 'type': type,
      if (targetDate != null) 'target_date': targetDate,
      if (targetStartSection != null)
        'target_start_section': targetStartSection,
      if (targetEndSection != null) 'target_end_section': targetEndSection,
      if (teacherOverride != null) 'teacher_override': teacherOverride,
      if (campusOverride != null) 'campus_override': campusOverride,
      if (roomOverride != null) 'room_override': roomOverride,
      if (addedCourseName != null) 'added_course_name': addedCourseName,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CourseExceptionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? semesterId,
      Value<String?>? courseId,
      Value<String?>? sourceMeetingId,
      Value<DateTime?>? sourceDate,
      Value<String>? type,
      Value<DateTime?>? targetDate,
      Value<int?>? targetStartSection,
      Value<int?>? targetEndSection,
      Value<String?>? teacherOverride,
      Value<String?>? campusOverride,
      Value<String?>? roomOverride,
      Value<String?>? addedCourseName,
      Value<String?>? note,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return CourseExceptionsCompanion(
      id: id ?? this.id,
      semesterId: semesterId ?? this.semesterId,
      courseId: courseId ?? this.courseId,
      sourceMeetingId: sourceMeetingId ?? this.sourceMeetingId,
      sourceDate: sourceDate ?? this.sourceDate,
      type: type ?? this.type,
      targetDate: targetDate ?? this.targetDate,
      targetStartSection: targetStartSection ?? this.targetStartSection,
      targetEndSection: targetEndSection ?? this.targetEndSection,
      teacherOverride: teacherOverride ?? this.teacherOverride,
      campusOverride: campusOverride ?? this.campusOverride,
      roomOverride: roomOverride ?? this.roomOverride,
      addedCourseName: addedCourseName ?? this.addedCourseName,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (semesterId.present) {
      map['semester_id'] = Variable<String>(semesterId.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (sourceMeetingId.present) {
      map['source_meeting_id'] = Variable<String>(sourceMeetingId.value);
    }
    if (sourceDate.present) {
      map['source_date'] = Variable<DateTime>(sourceDate.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<DateTime>(targetDate.value);
    }
    if (targetStartSection.present) {
      map['target_start_section'] = Variable<int>(targetStartSection.value);
    }
    if (targetEndSection.present) {
      map['target_end_section'] = Variable<int>(targetEndSection.value);
    }
    if (teacherOverride.present) {
      map['teacher_override'] = Variable<String>(teacherOverride.value);
    }
    if (campusOverride.present) {
      map['campus_override'] = Variable<String>(campusOverride.value);
    }
    if (roomOverride.present) {
      map['room_override'] = Variable<String>(roomOverride.value);
    }
    if (addedCourseName.present) {
      map['added_course_name'] = Variable<String>(addedCourseName.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CourseExceptionsCompanion(')
          ..write('id: $id, ')
          ..write('semesterId: $semesterId, ')
          ..write('courseId: $courseId, ')
          ..write('sourceMeetingId: $sourceMeetingId, ')
          ..write('sourceDate: $sourceDate, ')
          ..write('type: $type, ')
          ..write('targetDate: $targetDate, ')
          ..write('targetStartSection: $targetStartSection, ')
          ..write('targetEndSection: $targetEndSection, ')
          ..write('teacherOverride: $teacherOverride, ')
          ..write('campusOverride: $campusOverride, ')
          ..write('roomOverride: $roomOverride, ')
          ..write('addedCourseName: $addedCourseName, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportSnapshotsTable extends ImportSnapshots
    with TableInfo<$ImportSnapshotsTable, ImportSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _semesterIdMeta =
      const VerificationMeta('semesterId');
  @override
  late final GeneratedColumn<String> semesterId = GeneratedColumn<String>(
      'semester_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES semesters (id) ON DELETE CASCADE'));
  static const VerificationMeta _importedAtMeta =
      const VerificationMeta('importedAt');
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
      'imported_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _adapterVersionMeta =
      const VerificationMeta('adapterVersion');
  @override
  late final GeneratedColumn<String> adapterVersion = GeneratedColumn<String>(
      'adapter_version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _schemaVersionMeta =
      const VerificationMeta('schemaVersion');
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
      'schema_version', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _normalizedJsonMeta =
      const VerificationMeta('normalizedJson');
  @override
  late final GeneratedColumn<String> normalizedJson = GeneratedColumn<String>(
      'normalized_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
      'hash', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        semesterId,
        importedAt,
        adapterVersion,
        schemaVersion,
        normalizedJson,
        hash
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_snapshots';
  @override
  VerificationContext validateIntegrity(Insertable<ImportSnapshot> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('semester_id')) {
      context.handle(
          _semesterIdMeta,
          semesterId.isAcceptableOrUnknown(
              data['semester_id']!, _semesterIdMeta));
    } else if (isInserting) {
      context.missing(_semesterIdMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
          _importedAtMeta,
          importedAt.isAcceptableOrUnknown(
              data['imported_at']!, _importedAtMeta));
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    if (data.containsKey('adapter_version')) {
      context.handle(
          _adapterVersionMeta,
          adapterVersion.isAcceptableOrUnknown(
              data['adapter_version']!, _adapterVersionMeta));
    } else if (isInserting) {
      context.missing(_adapterVersionMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
          _schemaVersionMeta,
          schemaVersion.isAcceptableOrUnknown(
              data['schema_version']!, _schemaVersionMeta));
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('normalized_json')) {
      context.handle(
          _normalizedJsonMeta,
          normalizedJson.isAcceptableOrUnknown(
              data['normalized_json']!, _normalizedJsonMeta));
    } else if (isInserting) {
      context.missing(_normalizedJsonMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
          _hashMeta, hash.isAcceptableOrUnknown(data['hash']!, _hashMeta));
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImportSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportSnapshot(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      semesterId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}semester_id'])!,
      importedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}imported_at'])!,
      adapterVersion: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}adapter_version'])!,
      schemaVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}schema_version'])!,
      normalizedJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}normalized_json'])!,
      hash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}hash'])!,
    );
  }

  @override
  $ImportSnapshotsTable createAlias(String alias) {
    return $ImportSnapshotsTable(attachedDatabase, alias);
  }
}

class ImportSnapshot extends DataClass implements Insertable<ImportSnapshot> {
  final String id;
  final String semesterId;
  final DateTime importedAt;
  final String adapterVersion;
  final int schemaVersion;
  final String normalizedJson;
  final String hash;
  const ImportSnapshot(
      {required this.id,
      required this.semesterId,
      required this.importedAt,
      required this.adapterVersion,
      required this.schemaVersion,
      required this.normalizedJson,
      required this.hash});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['semester_id'] = Variable<String>(semesterId);
    map['imported_at'] = Variable<DateTime>(importedAt);
    map['adapter_version'] = Variable<String>(adapterVersion);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['normalized_json'] = Variable<String>(normalizedJson);
    map['hash'] = Variable<String>(hash);
    return map;
  }

  ImportSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return ImportSnapshotsCompanion(
      id: Value(id),
      semesterId: Value(semesterId),
      importedAt: Value(importedAt),
      adapterVersion: Value(adapterVersion),
      schemaVersion: Value(schemaVersion),
      normalizedJson: Value(normalizedJson),
      hash: Value(hash),
    );
  }

  factory ImportSnapshot.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportSnapshot(
      id: serializer.fromJson<String>(json['id']),
      semesterId: serializer.fromJson<String>(json['semesterId']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
      adapterVersion: serializer.fromJson<String>(json['adapterVersion']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      normalizedJson: serializer.fromJson<String>(json['normalizedJson']),
      hash: serializer.fromJson<String>(json['hash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'semesterId': serializer.toJson<String>(semesterId),
      'importedAt': serializer.toJson<DateTime>(importedAt),
      'adapterVersion': serializer.toJson<String>(adapterVersion),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'normalizedJson': serializer.toJson<String>(normalizedJson),
      'hash': serializer.toJson<String>(hash),
    };
  }

  ImportSnapshot copyWith(
          {String? id,
          String? semesterId,
          DateTime? importedAt,
          String? adapterVersion,
          int? schemaVersion,
          String? normalizedJson,
          String? hash}) =>
      ImportSnapshot(
        id: id ?? this.id,
        semesterId: semesterId ?? this.semesterId,
        importedAt: importedAt ?? this.importedAt,
        adapterVersion: adapterVersion ?? this.adapterVersion,
        schemaVersion: schemaVersion ?? this.schemaVersion,
        normalizedJson: normalizedJson ?? this.normalizedJson,
        hash: hash ?? this.hash,
      );
  ImportSnapshot copyWithCompanion(ImportSnapshotsCompanion data) {
    return ImportSnapshot(
      id: data.id.present ? data.id.value : this.id,
      semesterId:
          data.semesterId.present ? data.semesterId.value : this.semesterId,
      importedAt:
          data.importedAt.present ? data.importedAt.value : this.importedAt,
      adapterVersion: data.adapterVersion.present
          ? data.adapterVersion.value
          : this.adapterVersion,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      normalizedJson: data.normalizedJson.present
          ? data.normalizedJson.value
          : this.normalizedJson,
      hash: data.hash.present ? data.hash.value : this.hash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportSnapshot(')
          ..write('id: $id, ')
          ..write('semesterId: $semesterId, ')
          ..write('importedAt: $importedAt, ')
          ..write('adapterVersion: $adapterVersion, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('normalizedJson: $normalizedJson, ')
          ..write('hash: $hash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, semesterId, importedAt, adapterVersion,
      schemaVersion, normalizedJson, hash);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportSnapshot &&
          other.id == this.id &&
          other.semesterId == this.semesterId &&
          other.importedAt == this.importedAt &&
          other.adapterVersion == this.adapterVersion &&
          other.schemaVersion == this.schemaVersion &&
          other.normalizedJson == this.normalizedJson &&
          other.hash == this.hash);
}

class ImportSnapshotsCompanion extends UpdateCompanion<ImportSnapshot> {
  final Value<String> id;
  final Value<String> semesterId;
  final Value<DateTime> importedAt;
  final Value<String> adapterVersion;
  final Value<int> schemaVersion;
  final Value<String> normalizedJson;
  final Value<String> hash;
  final Value<int> rowid;
  const ImportSnapshotsCompanion({
    this.id = const Value.absent(),
    this.semesterId = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.adapterVersion = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.normalizedJson = const Value.absent(),
    this.hash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportSnapshotsCompanion.insert({
    required String id,
    required String semesterId,
    required DateTime importedAt,
    required String adapterVersion,
    required int schemaVersion,
    required String normalizedJson,
    required String hash,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        semesterId = Value(semesterId),
        importedAt = Value(importedAt),
        adapterVersion = Value(adapterVersion),
        schemaVersion = Value(schemaVersion),
        normalizedJson = Value(normalizedJson),
        hash = Value(hash);
  static Insertable<ImportSnapshot> custom({
    Expression<String>? id,
    Expression<String>? semesterId,
    Expression<DateTime>? importedAt,
    Expression<String>? adapterVersion,
    Expression<int>? schemaVersion,
    Expression<String>? normalizedJson,
    Expression<String>? hash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (semesterId != null) 'semester_id': semesterId,
      if (importedAt != null) 'imported_at': importedAt,
      if (adapterVersion != null) 'adapter_version': adapterVersion,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (normalizedJson != null) 'normalized_json': normalizedJson,
      if (hash != null) 'hash': hash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportSnapshotsCompanion copyWith(
      {Value<String>? id,
      Value<String>? semesterId,
      Value<DateTime>? importedAt,
      Value<String>? adapterVersion,
      Value<int>? schemaVersion,
      Value<String>? normalizedJson,
      Value<String>? hash,
      Value<int>? rowid}) {
    return ImportSnapshotsCompanion(
      id: id ?? this.id,
      semesterId: semesterId ?? this.semesterId,
      importedAt: importedAt ?? this.importedAt,
      adapterVersion: adapterVersion ?? this.adapterVersion,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      normalizedJson: normalizedJson ?? this.normalizedJson,
      hash: hash ?? this.hash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (semesterId.present) {
      map['semester_id'] = Variable<String>(semesterId.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (adapterVersion.present) {
      map['adapter_version'] = Variable<String>(adapterVersion.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (normalizedJson.present) {
      map['normalized_json'] = Variable<String>(normalizedJson.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('semesterId: $semesterId, ')
          ..write('importedAt: $importedAt, ')
          ..write('adapterVersion: $adapterVersion, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('normalizedJson: $normalizedJson, ')
          ..write('hash: $hash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeletedSourceItemsTable extends DeletedSourceItems
    with TableInfo<$DeletedSourceItemsTable, DeletedSourceItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeletedSourceItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _semesterIdMeta =
      const VerificationMeta('semesterId');
  @override
  late final GeneratedColumn<String> semesterId = GeneratedColumn<String>(
      'semester_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES semesters (id) ON DELETE CASCADE'));
  static const VerificationMeta _sourceCourseKeyMeta =
      const VerificationMeta('sourceCourseKey');
  @override
  late final GeneratedColumn<String> sourceCourseKey = GeneratedColumn<String>(
      'source_course_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeetingKeyMeta =
      const VerificationMeta('sourceMeetingKey');
  @override
  late final GeneratedColumn<String> sourceMeetingKey = GeneratedColumn<String>(
      'source_meeting_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, semesterId, sourceCourseKey, sourceMeetingKey, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deleted_source_items';
  @override
  VerificationContext validateIntegrity(Insertable<DeletedSourceItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('semester_id')) {
      context.handle(
          _semesterIdMeta,
          semesterId.isAcceptableOrUnknown(
              data['semester_id']!, _semesterIdMeta));
    } else if (isInserting) {
      context.missing(_semesterIdMeta);
    }
    if (data.containsKey('source_course_key')) {
      context.handle(
          _sourceCourseKeyMeta,
          sourceCourseKey.isAcceptableOrUnknown(
              data['source_course_key']!, _sourceCourseKeyMeta));
    } else if (isInserting) {
      context.missing(_sourceCourseKeyMeta);
    }
    if (data.containsKey('source_meeting_key')) {
      context.handle(
          _sourceMeetingKeyMeta,
          sourceMeetingKey.isAcceptableOrUnknown(
              data['source_meeting_key']!, _sourceMeetingKeyMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    } else if (isInserting) {
      context.missing(_deletedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeletedSourceItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeletedSourceItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      semesterId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}semester_id'])!,
      sourceCourseKey: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}source_course_key'])!,
      sourceMeetingKey: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}source_meeting_key']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at'])!,
    );
  }

  @override
  $DeletedSourceItemsTable createAlias(String alias) {
    return $DeletedSourceItemsTable(attachedDatabase, alias);
  }
}

class DeletedSourceItem extends DataClass
    implements Insertable<DeletedSourceItem> {
  final String id;
  final String semesterId;
  final String sourceCourseKey;
  final String? sourceMeetingKey;
  final DateTime deletedAt;
  const DeletedSourceItem(
      {required this.id,
      required this.semesterId,
      required this.sourceCourseKey,
      this.sourceMeetingKey,
      required this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['semester_id'] = Variable<String>(semesterId);
    map['source_course_key'] = Variable<String>(sourceCourseKey);
    if (!nullToAbsent || sourceMeetingKey != null) {
      map['source_meeting_key'] = Variable<String>(sourceMeetingKey);
    }
    map['deleted_at'] = Variable<DateTime>(deletedAt);
    return map;
  }

  DeletedSourceItemsCompanion toCompanion(bool nullToAbsent) {
    return DeletedSourceItemsCompanion(
      id: Value(id),
      semesterId: Value(semesterId),
      sourceCourseKey: Value(sourceCourseKey),
      sourceMeetingKey: sourceMeetingKey == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceMeetingKey),
      deletedAt: Value(deletedAt),
    );
  }

  factory DeletedSourceItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeletedSourceItem(
      id: serializer.fromJson<String>(json['id']),
      semesterId: serializer.fromJson<String>(json['semesterId']),
      sourceCourseKey: serializer.fromJson<String>(json['sourceCourseKey']),
      sourceMeetingKey: serializer.fromJson<String?>(json['sourceMeetingKey']),
      deletedAt: serializer.fromJson<DateTime>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'semesterId': serializer.toJson<String>(semesterId),
      'sourceCourseKey': serializer.toJson<String>(sourceCourseKey),
      'sourceMeetingKey': serializer.toJson<String?>(sourceMeetingKey),
      'deletedAt': serializer.toJson<DateTime>(deletedAt),
    };
  }

  DeletedSourceItem copyWith(
          {String? id,
          String? semesterId,
          String? sourceCourseKey,
          Value<String?> sourceMeetingKey = const Value.absent(),
          DateTime? deletedAt}) =>
      DeletedSourceItem(
        id: id ?? this.id,
        semesterId: semesterId ?? this.semesterId,
        sourceCourseKey: sourceCourseKey ?? this.sourceCourseKey,
        sourceMeetingKey: sourceMeetingKey.present
            ? sourceMeetingKey.value
            : this.sourceMeetingKey,
        deletedAt: deletedAt ?? this.deletedAt,
      );
  DeletedSourceItem copyWithCompanion(DeletedSourceItemsCompanion data) {
    return DeletedSourceItem(
      id: data.id.present ? data.id.value : this.id,
      semesterId:
          data.semesterId.present ? data.semesterId.value : this.semesterId,
      sourceCourseKey: data.sourceCourseKey.present
          ? data.sourceCourseKey.value
          : this.sourceCourseKey,
      sourceMeetingKey: data.sourceMeetingKey.present
          ? data.sourceMeetingKey.value
          : this.sourceMeetingKey,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeletedSourceItem(')
          ..write('id: $id, ')
          ..write('semesterId: $semesterId, ')
          ..write('sourceCourseKey: $sourceCourseKey, ')
          ..write('sourceMeetingKey: $sourceMeetingKey, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, semesterId, sourceCourseKey, sourceMeetingKey, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeletedSourceItem &&
          other.id == this.id &&
          other.semesterId == this.semesterId &&
          other.sourceCourseKey == this.sourceCourseKey &&
          other.sourceMeetingKey == this.sourceMeetingKey &&
          other.deletedAt == this.deletedAt);
}

class DeletedSourceItemsCompanion extends UpdateCompanion<DeletedSourceItem> {
  final Value<String> id;
  final Value<String> semesterId;
  final Value<String> sourceCourseKey;
  final Value<String?> sourceMeetingKey;
  final Value<DateTime> deletedAt;
  final Value<int> rowid;
  const DeletedSourceItemsCompanion({
    this.id = const Value.absent(),
    this.semesterId = const Value.absent(),
    this.sourceCourseKey = const Value.absent(),
    this.sourceMeetingKey = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeletedSourceItemsCompanion.insert({
    required String id,
    required String semesterId,
    required String sourceCourseKey,
    this.sourceMeetingKey = const Value.absent(),
    required DateTime deletedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        semesterId = Value(semesterId),
        sourceCourseKey = Value(sourceCourseKey),
        deletedAt = Value(deletedAt);
  static Insertable<DeletedSourceItem> custom({
    Expression<String>? id,
    Expression<String>? semesterId,
    Expression<String>? sourceCourseKey,
    Expression<String>? sourceMeetingKey,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (semesterId != null) 'semester_id': semesterId,
      if (sourceCourseKey != null) 'source_course_key': sourceCourseKey,
      if (sourceMeetingKey != null) 'source_meeting_key': sourceMeetingKey,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeletedSourceItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? semesterId,
      Value<String>? sourceCourseKey,
      Value<String?>? sourceMeetingKey,
      Value<DateTime>? deletedAt,
      Value<int>? rowid}) {
    return DeletedSourceItemsCompanion(
      id: id ?? this.id,
      semesterId: semesterId ?? this.semesterId,
      sourceCourseKey: sourceCourseKey ?? this.sourceCourseKey,
      sourceMeetingKey: sourceMeetingKey ?? this.sourceMeetingKey,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (semesterId.present) {
      map['semester_id'] = Variable<String>(semesterId.value);
    }
    if (sourceCourseKey.present) {
      map['source_course_key'] = Variable<String>(sourceCourseKey.value);
    }
    if (sourceMeetingKey.present) {
      map['source_meeting_key'] = Variable<String>(sourceMeetingKey.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeletedSourceItemsCompanion(')
          ..write('id: $id, ')
          ..write('semesterId: $semesterId, ')
          ..write('sourceCourseKey: $sourceCourseKey, ')
          ..write('sourceMeetingKey: $sourceMeetingKey, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(Insertable<AppSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory AppSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) => AppSetting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SemestersTable semesters = $SemestersTable(this);
  late final $CoursesTable courses = $CoursesTable(this);
  late final $MeetingRulesTable meetingRules = $MeetingRulesTable(this);
  late final $CourseExceptionsTable courseExceptions =
      $CourseExceptionsTable(this);
  late final $ImportSnapshotsTable importSnapshots =
      $ImportSnapshotsTable(this);
  late final $DeletedSourceItemsTable deletedSourceItems =
      $DeletedSourceItemsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        semesters,
        courses,
        meetingRules,
        courseExceptions,
        importSnapshots,
        deletedSourceItems,
        appSettings
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('semesters',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('courses', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('courses',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('meeting_rules', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('semesters',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('course_exceptions', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('semesters',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('import_snapshots', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('semesters',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('deleted_source_items', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$SemestersTableCreateCompanionBuilder = SemestersCompanion Function({
  required String id,
  required String academicYear,
  required int term,
  required String label,
  Value<String?> remoteTermKey,
  Value<String?> calendarId,
  Value<int?> calendarRevision,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$SemestersTableUpdateCompanionBuilder = SemestersCompanion Function({
  Value<String> id,
  Value<String> academicYear,
  Value<int> term,
  Value<String> label,
  Value<String?> remoteTermKey,
  Value<String?> calendarId,
  Value<int?> calendarRevision,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$SemestersTableReferences
    extends BaseReferences<_$AppDatabase, $SemestersTable, Semester> {
  $$SemestersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CoursesTable, List<Course>> _coursesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.courses,
          aliasName: 'semesters__id__courses__semester_id');

  $$CoursesTableProcessedTableManager get coursesRefs {
    final manager = $$CoursesTableTableManager($_db, $_db.courses)
        .filter((f) => f.semesterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_coursesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$CourseExceptionsTable, List<CourseException>>
      _courseExceptionsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.courseExceptions,
              aliasName: 'semesters__id__course_exceptions__semester_id');

  $$CourseExceptionsTableProcessedTableManager get courseExceptionsRefs {
    final manager = $$CourseExceptionsTableTableManager(
            $_db, $_db.courseExceptions)
        .filter((f) => f.semesterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_courseExceptionsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ImportSnapshotsTable, List<ImportSnapshot>>
      _importSnapshotsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.importSnapshots,
              aliasName: 'semesters__id__import_snapshots__semester_id');

  $$ImportSnapshotsTableProcessedTableManager get importSnapshotsRefs {
    final manager = $$ImportSnapshotsTableTableManager(
            $_db, $_db.importSnapshots)
        .filter((f) => f.semesterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_importSnapshotsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$DeletedSourceItemsTable, List<DeletedSourceItem>>
      _deletedSourceItemsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.deletedSourceItems,
              aliasName: 'semesters__id__deleted_source_items__semester_id');

  $$DeletedSourceItemsTableProcessedTableManager get deletedSourceItemsRefs {
    final manager = $$DeletedSourceItemsTableTableManager(
            $_db, $_db.deletedSourceItems)
        .filter((f) => f.semesterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_deletedSourceItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SemestersTableFilterComposer
    extends Composer<_$AppDatabase, $SemestersTable> {
  $$SemestersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get academicYear => $composableBuilder(
      column: $table.academicYear, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get term => $composableBuilder(
      column: $table.term, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteTermKey => $composableBuilder(
      column: $table.remoteTermKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get calendarId => $composableBuilder(
      column: $table.calendarId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get calendarRevision => $composableBuilder(
      column: $table.calendarRevision,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> coursesRefs(
      Expression<bool> Function($$CoursesTableFilterComposer f) f) {
    final $$CoursesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.courses,
        getReferencedColumn: (t) => t.semesterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CoursesTableFilterComposer(
              $db: $db,
              $table: $db.courses,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> courseExceptionsRefs(
      Expression<bool> Function($$CourseExceptionsTableFilterComposer f) f) {
    final $$CourseExceptionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.courseExceptions,
        getReferencedColumn: (t) => t.semesterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CourseExceptionsTableFilterComposer(
              $db: $db,
              $table: $db.courseExceptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> importSnapshotsRefs(
      Expression<bool> Function($$ImportSnapshotsTableFilterComposer f) f) {
    final $$ImportSnapshotsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.importSnapshots,
        getReferencedColumn: (t) => t.semesterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ImportSnapshotsTableFilterComposer(
              $db: $db,
              $table: $db.importSnapshots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> deletedSourceItemsRefs(
      Expression<bool> Function($$DeletedSourceItemsTableFilterComposer f) f) {
    final $$DeletedSourceItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.deletedSourceItems,
        getReferencedColumn: (t) => t.semesterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DeletedSourceItemsTableFilterComposer(
              $db: $db,
              $table: $db.deletedSourceItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SemestersTableOrderingComposer
    extends Composer<_$AppDatabase, $SemestersTable> {
  $$SemestersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get academicYear => $composableBuilder(
      column: $table.academicYear,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get term => $composableBuilder(
      column: $table.term, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteTermKey => $composableBuilder(
      column: $table.remoteTermKey,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get calendarId => $composableBuilder(
      column: $table.calendarId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get calendarRevision => $composableBuilder(
      column: $table.calendarRevision,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$SemestersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SemestersTable> {
  $$SemestersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get academicYear => $composableBuilder(
      column: $table.academicYear, builder: (column) => column);

  GeneratedColumn<int> get term =>
      $composableBuilder(column: $table.term, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get remoteTermKey => $composableBuilder(
      column: $table.remoteTermKey, builder: (column) => column);

  GeneratedColumn<String> get calendarId => $composableBuilder(
      column: $table.calendarId, builder: (column) => column);

  GeneratedColumn<int> get calendarRevision => $composableBuilder(
      column: $table.calendarRevision, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> coursesRefs<T extends Object>(
      Expression<T> Function($$CoursesTableAnnotationComposer a) f) {
    final $$CoursesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.courses,
        getReferencedColumn: (t) => t.semesterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CoursesTableAnnotationComposer(
              $db: $db,
              $table: $db.courses,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> courseExceptionsRefs<T extends Object>(
      Expression<T> Function($$CourseExceptionsTableAnnotationComposer a) f) {
    final $$CourseExceptionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.courseExceptions,
        getReferencedColumn: (t) => t.semesterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CourseExceptionsTableAnnotationComposer(
              $db: $db,
              $table: $db.courseExceptions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> importSnapshotsRefs<T extends Object>(
      Expression<T> Function($$ImportSnapshotsTableAnnotationComposer a) f) {
    final $$ImportSnapshotsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.importSnapshots,
        getReferencedColumn: (t) => t.semesterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ImportSnapshotsTableAnnotationComposer(
              $db: $db,
              $table: $db.importSnapshots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> deletedSourceItemsRefs<T extends Object>(
      Expression<T> Function($$DeletedSourceItemsTableAnnotationComposer a) f) {
    final $$DeletedSourceItemsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.deletedSourceItems,
            getReferencedColumn: (t) => t.semesterId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$DeletedSourceItemsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.deletedSourceItems,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$SemestersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SemestersTable,
    Semester,
    $$SemestersTableFilterComposer,
    $$SemestersTableOrderingComposer,
    $$SemestersTableAnnotationComposer,
    $$SemestersTableCreateCompanionBuilder,
    $$SemestersTableUpdateCompanionBuilder,
    (Semester, $$SemestersTableReferences),
    Semester,
    PrefetchHooks Function(
        {bool coursesRefs,
        bool courseExceptionsRefs,
        bool importSnapshotsRefs,
        bool deletedSourceItemsRefs})> {
  $$SemestersTableTableManager(_$AppDatabase db, $SemestersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SemestersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SemestersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SemestersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> academicYear = const Value.absent(),
            Value<int> term = const Value.absent(),
            Value<String> label = const Value.absent(),
            Value<String?> remoteTermKey = const Value.absent(),
            Value<String?> calendarId = const Value.absent(),
            Value<int?> calendarRevision = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SemestersCompanion(
            id: id,
            academicYear: academicYear,
            term: term,
            label: label,
            remoteTermKey: remoteTermKey,
            calendarId: calendarId,
            calendarRevision: calendarRevision,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String academicYear,
            required int term,
            required String label,
            Value<String?> remoteTermKey = const Value.absent(),
            Value<String?> calendarId = const Value.absent(),
            Value<int?> calendarRevision = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SemestersCompanion.insert(
            id: id,
            academicYear: academicYear,
            term: term,
            label: label,
            remoteTermKey: remoteTermKey,
            calendarId: calendarId,
            calendarRevision: calendarRevision,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SemestersTable, Semester>(table),
                    $$SemestersTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {coursesRefs = false,
              courseExceptionsRefs = false,
              importSnapshotsRefs = false,
              deletedSourceItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (coursesRefs) db.courses,
                if (courseExceptionsRefs) db.courseExceptions,
                if (importSnapshotsRefs) db.importSnapshots,
                if (deletedSourceItemsRefs) db.deletedSourceItems
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (coursesRefs)
                    await $_getPrefetchedData<Semester, $SemestersTable,
                            Course>(
                        currentTable: table,
                        referencedTable:
                            $$SemestersTableReferences._coursesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SemestersTableReferences(db, table, p0)
                                .coursesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.semesterId == item.id),
                        typedResults: items),
                  if (courseExceptionsRefs)
                    await $_getPrefetchedData<Semester, $SemestersTable,
                            CourseException>(
                        currentTable: table,
                        referencedTable: $$SemestersTableReferences
                            ._courseExceptionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SemestersTableReferences(db, table, p0)
                                .courseExceptionsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.semesterId == item.id),
                        typedResults: items),
                  if (importSnapshotsRefs)
                    await $_getPrefetchedData<Semester, $SemestersTable,
                            ImportSnapshot>(
                        currentTable: table,
                        referencedTable: $$SemestersTableReferences
                            ._importSnapshotsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SemestersTableReferences(db, table, p0)
                                .importSnapshotsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.semesterId == item.id),
                        typedResults: items),
                  if (deletedSourceItemsRefs)
                    await $_getPrefetchedData<Semester, $SemestersTable,
                            DeletedSourceItem>(
                        currentTable: table,
                        referencedTable: $$SemestersTableReferences
                            ._deletedSourceItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SemestersTableReferences(db, table, p0)
                                .deletedSourceItemsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.semesterId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SemestersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SemestersTable,
    Semester,
    $$SemestersTableFilterComposer,
    $$SemestersTableOrderingComposer,
    $$SemestersTableAnnotationComposer,
    $$SemestersTableCreateCompanionBuilder,
    $$SemestersTableUpdateCompanionBuilder,
    (Semester, $$SemestersTableReferences),
    Semester,
    PrefetchHooks Function(
        {bool coursesRefs,
        bool courseExceptionsRefs,
        bool importSnapshotsRefs,
        bool deletedSourceItemsRefs})>;
typedef $$CoursesTableCreateCompanionBuilder = CoursesCompanion Function({
  required String id,
  required String semesterId,
  required String sourceType,
  Value<String?> sourceCourseKey,
  required String name,
  Value<String> nameKey,
  Value<String?> code,
  Value<String?> teachingClass,
  Value<double?> credits,
  Value<String?> assessment,
  Value<String?> note,
  Value<int?> colorOverride,
  Value<bool> hidden,
  Value<bool> deleted,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$CoursesTableUpdateCompanionBuilder = CoursesCompanion Function({
  Value<String> id,
  Value<String> semesterId,
  Value<String> sourceType,
  Value<String?> sourceCourseKey,
  Value<String> name,
  Value<String> nameKey,
  Value<String?> code,
  Value<String?> teachingClass,
  Value<double?> credits,
  Value<String?> assessment,
  Value<String?> note,
  Value<int?> colorOverride,
  Value<bool> hidden,
  Value<bool> deleted,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$CoursesTableReferences
    extends BaseReferences<_$AppDatabase, $CoursesTable, Course> {
  $$CoursesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SemestersTable _semesterIdTable(_$AppDatabase db) =>
      db.semesters.createAlias('courses__semester_id__semesters__id');

  $$SemestersTableProcessedTableManager get semesterId {
    final $_column = $_itemColumn<String>('semester_id')!;

    final manager = $$SemestersTableTableManager($_db, $_db.semesters)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_semesterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$MeetingRulesTable, List<StoredMeetingRule>>
      _meetingRulesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.meetingRules,
              aliasName: 'courses__id__meeting_rules__course_id');

  $$MeetingRulesTableProcessedTableManager get meetingRulesRefs {
    final manager = $$MeetingRulesTableTableManager($_db, $_db.meetingRules)
        .filter((f) => f.courseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_meetingRulesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CoursesTableFilterComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceType => $composableBuilder(
      column: $table.sourceType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceCourseKey => $composableBuilder(
      column: $table.sourceCourseKey,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nameKey => $composableBuilder(
      column: $table.nameKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get teachingClass => $composableBuilder(
      column: $table.teachingClass, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get credits => $composableBuilder(
      column: $table.credits, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get assessment => $composableBuilder(
      column: $table.assessment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get colorOverride => $composableBuilder(
      column: $table.colorOverride, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hidden => $composableBuilder(
      column: $table.hidden, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$SemestersTableFilterComposer get semesterId {
    final $$SemestersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.semesterId,
        referencedTable: $db.semesters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SemestersTableFilterComposer(
              $db: $db,
              $table: $db.semesters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> meetingRulesRefs(
      Expression<bool> Function($$MeetingRulesTableFilterComposer f) f) {
    final $$MeetingRulesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.meetingRules,
        getReferencedColumn: (t) => t.courseId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MeetingRulesTableFilterComposer(
              $db: $db,
              $table: $db.meetingRules,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CoursesTableOrderingComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceType => $composableBuilder(
      column: $table.sourceType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceCourseKey => $composableBuilder(
      column: $table.sourceCourseKey,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nameKey => $composableBuilder(
      column: $table.nameKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get teachingClass => $composableBuilder(
      column: $table.teachingClass,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get credits => $composableBuilder(
      column: $table.credits, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get assessment => $composableBuilder(
      column: $table.assessment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get colorOverride => $composableBuilder(
      column: $table.colorOverride,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hidden => $composableBuilder(
      column: $table.hidden, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$SemestersTableOrderingComposer get semesterId {
    final $$SemestersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.semesterId,
        referencedTable: $db.semesters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SemestersTableOrderingComposer(
              $db: $db,
              $table: $db.semesters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CoursesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
      column: $table.sourceType, builder: (column) => column);

  GeneratedColumn<String> get sourceCourseKey => $composableBuilder(
      column: $table.sourceCourseKey, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameKey =>
      $composableBuilder(column: $table.nameKey, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get teachingClass => $composableBuilder(
      column: $table.teachingClass, builder: (column) => column);

  GeneratedColumn<double> get credits =>
      $composableBuilder(column: $table.credits, builder: (column) => column);

  GeneratedColumn<String> get assessment => $composableBuilder(
      column: $table.assessment, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get colorOverride => $composableBuilder(
      column: $table.colorOverride, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$SemestersTableAnnotationComposer get semesterId {
    final $$SemestersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.semesterId,
        referencedTable: $db.semesters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SemestersTableAnnotationComposer(
              $db: $db,
              $table: $db.semesters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> meetingRulesRefs<T extends Object>(
      Expression<T> Function($$MeetingRulesTableAnnotationComposer a) f) {
    final $$MeetingRulesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.meetingRules,
        getReferencedColumn: (t) => t.courseId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MeetingRulesTableAnnotationComposer(
              $db: $db,
              $table: $db.meetingRules,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CoursesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CoursesTable,
    Course,
    $$CoursesTableFilterComposer,
    $$CoursesTableOrderingComposer,
    $$CoursesTableAnnotationComposer,
    $$CoursesTableCreateCompanionBuilder,
    $$CoursesTableUpdateCompanionBuilder,
    (Course, $$CoursesTableReferences),
    Course,
    PrefetchHooks Function({bool semesterId, bool meetingRulesRefs})> {
  $$CoursesTableTableManager(_$AppDatabase db, $CoursesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoursesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoursesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoursesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> semesterId = const Value.absent(),
            Value<String> sourceType = const Value.absent(),
            Value<String?> sourceCourseKey = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> nameKey = const Value.absent(),
            Value<String?> code = const Value.absent(),
            Value<String?> teachingClass = const Value.absent(),
            Value<double?> credits = const Value.absent(),
            Value<String?> assessment = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int?> colorOverride = const Value.absent(),
            Value<bool> hidden = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CoursesCompanion(
            id: id,
            semesterId: semesterId,
            sourceType: sourceType,
            sourceCourseKey: sourceCourseKey,
            name: name,
            nameKey: nameKey,
            code: code,
            teachingClass: teachingClass,
            credits: credits,
            assessment: assessment,
            note: note,
            colorOverride: colorOverride,
            hidden: hidden,
            deleted: deleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String semesterId,
            required String sourceType,
            Value<String?> sourceCourseKey = const Value.absent(),
            required String name,
            Value<String> nameKey = const Value.absent(),
            Value<String?> code = const Value.absent(),
            Value<String?> teachingClass = const Value.absent(),
            Value<double?> credits = const Value.absent(),
            Value<String?> assessment = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int?> colorOverride = const Value.absent(),
            Value<bool> hidden = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CoursesCompanion.insert(
            id: id,
            semesterId: semesterId,
            sourceType: sourceType,
            sourceCourseKey: sourceCourseKey,
            name: name,
            nameKey: nameKey,
            code: code,
            teachingClass: teachingClass,
            credits: credits,
            assessment: assessment,
            note: note,
            colorOverride: colorOverride,
            hidden: hidden,
            deleted: deleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CoursesTable, Course>(table),
                    $$CoursesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {semesterId = false, meetingRulesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (meetingRulesRefs) db.meetingRules],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (semesterId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.semesterId,
                    referencedTable:
                        $$CoursesTableReferences._semesterIdTable(db),
                    referencedColumn:
                        $$CoursesTableReferences._semesterIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (meetingRulesRefs)
                    await $_getPrefetchedData<Course, $CoursesTable,
                            StoredMeetingRule>(
                        currentTable: table,
                        referencedTable:
                            $$CoursesTableReferences._meetingRulesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CoursesTableReferences(db, table, p0)
                                .meetingRulesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.courseId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$CoursesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CoursesTable,
    Course,
    $$CoursesTableFilterComposer,
    $$CoursesTableOrderingComposer,
    $$CoursesTableAnnotationComposer,
    $$CoursesTableCreateCompanionBuilder,
    $$CoursesTableUpdateCompanionBuilder,
    (Course, $$CoursesTableReferences),
    Course,
    PrefetchHooks Function({bool semesterId, bool meetingRulesRefs})>;
typedef $$MeetingRulesTableCreateCompanionBuilder = MeetingRulesCompanion
    Function({
  required String id,
  required String courseId,
  Value<String?> sourceMeetingKey,
  required int weekday,
  required int startSection,
  required int endSection,
  Value<String?> teacher,
  Value<String?> campus,
  Value<String?> room,
  required int weekMask,
  required String rawWeekText,
  Value<int> rowid,
});
typedef $$MeetingRulesTableUpdateCompanionBuilder = MeetingRulesCompanion
    Function({
  Value<String> id,
  Value<String> courseId,
  Value<String?> sourceMeetingKey,
  Value<int> weekday,
  Value<int> startSection,
  Value<int> endSection,
  Value<String?> teacher,
  Value<String?> campus,
  Value<String?> room,
  Value<int> weekMask,
  Value<String> rawWeekText,
  Value<int> rowid,
});

final class $$MeetingRulesTableReferences extends BaseReferences<_$AppDatabase,
    $MeetingRulesTable, StoredMeetingRule> {
  $$MeetingRulesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CoursesTable _courseIdTable(_$AppDatabase db) =>
      db.courses.createAlias('meeting_rules__course_id__courses__id');

  $$CoursesTableProcessedTableManager get courseId {
    final $_column = $_itemColumn<String>('course_id')!;

    final manager = $$CoursesTableTableManager($_db, $_db.courses)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_courseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$MeetingRulesTableFilterComposer
    extends Composer<_$AppDatabase, $MeetingRulesTable> {
  $$MeetingRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceMeetingKey => $composableBuilder(
      column: $table.sourceMeetingKey,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get weekday => $composableBuilder(
      column: $table.weekday, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startSection => $composableBuilder(
      column: $table.startSection, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get endSection => $composableBuilder(
      column: $table.endSection, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get teacher => $composableBuilder(
      column: $table.teacher, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get campus => $composableBuilder(
      column: $table.campus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get room => $composableBuilder(
      column: $table.room, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get weekMask => $composableBuilder(
      column: $table.weekMask, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawWeekText => $composableBuilder(
      column: $table.rawWeekText, builder: (column) => ColumnFilters(column));

  $$CoursesTableFilterComposer get courseId {
    final $$CoursesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.courseId,
        referencedTable: $db.courses,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CoursesTableFilterComposer(
              $db: $db,
              $table: $db.courses,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MeetingRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $MeetingRulesTable> {
  $$MeetingRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceMeetingKey => $composableBuilder(
      column: $table.sourceMeetingKey,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get weekday => $composableBuilder(
      column: $table.weekday, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startSection => $composableBuilder(
      column: $table.startSection,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get endSection => $composableBuilder(
      column: $table.endSection, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get teacher => $composableBuilder(
      column: $table.teacher, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get campus => $composableBuilder(
      column: $table.campus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get room => $composableBuilder(
      column: $table.room, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get weekMask => $composableBuilder(
      column: $table.weekMask, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawWeekText => $composableBuilder(
      column: $table.rawWeekText, builder: (column) => ColumnOrderings(column));

  $$CoursesTableOrderingComposer get courseId {
    final $$CoursesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.courseId,
        referencedTable: $db.courses,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CoursesTableOrderingComposer(
              $db: $db,
              $table: $db.courses,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MeetingRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MeetingRulesTable> {
  $$MeetingRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceMeetingKey => $composableBuilder(
      column: $table.sourceMeetingKey, builder: (column) => column);

  GeneratedColumn<int> get weekday =>
      $composableBuilder(column: $table.weekday, builder: (column) => column);

  GeneratedColumn<int> get startSection => $composableBuilder(
      column: $table.startSection, builder: (column) => column);

  GeneratedColumn<int> get endSection => $composableBuilder(
      column: $table.endSection, builder: (column) => column);

  GeneratedColumn<String> get teacher =>
      $composableBuilder(column: $table.teacher, builder: (column) => column);

  GeneratedColumn<String> get campus =>
      $composableBuilder(column: $table.campus, builder: (column) => column);

  GeneratedColumn<String> get room =>
      $composableBuilder(column: $table.room, builder: (column) => column);

  GeneratedColumn<int> get weekMask =>
      $composableBuilder(column: $table.weekMask, builder: (column) => column);

  GeneratedColumn<String> get rawWeekText => $composableBuilder(
      column: $table.rawWeekText, builder: (column) => column);

  $$CoursesTableAnnotationComposer get courseId {
    final $$CoursesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.courseId,
        referencedTable: $db.courses,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CoursesTableAnnotationComposer(
              $db: $db,
              $table: $db.courses,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MeetingRulesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MeetingRulesTable,
    StoredMeetingRule,
    $$MeetingRulesTableFilterComposer,
    $$MeetingRulesTableOrderingComposer,
    $$MeetingRulesTableAnnotationComposer,
    $$MeetingRulesTableCreateCompanionBuilder,
    $$MeetingRulesTableUpdateCompanionBuilder,
    (StoredMeetingRule, $$MeetingRulesTableReferences),
    StoredMeetingRule,
    PrefetchHooks Function({bool courseId})> {
  $$MeetingRulesTableTableManager(_$AppDatabase db, $MeetingRulesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MeetingRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MeetingRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MeetingRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> courseId = const Value.absent(),
            Value<String?> sourceMeetingKey = const Value.absent(),
            Value<int> weekday = const Value.absent(),
            Value<int> startSection = const Value.absent(),
            Value<int> endSection = const Value.absent(),
            Value<String?> teacher = const Value.absent(),
            Value<String?> campus = const Value.absent(),
            Value<String?> room = const Value.absent(),
            Value<int> weekMask = const Value.absent(),
            Value<String> rawWeekText = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MeetingRulesCompanion(
            id: id,
            courseId: courseId,
            sourceMeetingKey: sourceMeetingKey,
            weekday: weekday,
            startSection: startSection,
            endSection: endSection,
            teacher: teacher,
            campus: campus,
            room: room,
            weekMask: weekMask,
            rawWeekText: rawWeekText,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String courseId,
            Value<String?> sourceMeetingKey = const Value.absent(),
            required int weekday,
            required int startSection,
            required int endSection,
            Value<String?> teacher = const Value.absent(),
            Value<String?> campus = const Value.absent(),
            Value<String?> room = const Value.absent(),
            required int weekMask,
            required String rawWeekText,
            Value<int> rowid = const Value.absent(),
          }) =>
              MeetingRulesCompanion.insert(
            id: id,
            courseId: courseId,
            sourceMeetingKey: sourceMeetingKey,
            weekday: weekday,
            startSection: startSection,
            endSection: endSection,
            teacher: teacher,
            campus: campus,
            room: room,
            weekMask: weekMask,
            rawWeekText: rawWeekText,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MeetingRulesTable, StoredMeetingRule>(table),
                    $$MeetingRulesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({courseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (courseId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.courseId,
                    referencedTable:
                        $$MeetingRulesTableReferences._courseIdTable(db),
                    referencedColumn:
                        $$MeetingRulesTableReferences._courseIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$MeetingRulesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MeetingRulesTable,
    StoredMeetingRule,
    $$MeetingRulesTableFilterComposer,
    $$MeetingRulesTableOrderingComposer,
    $$MeetingRulesTableAnnotationComposer,
    $$MeetingRulesTableCreateCompanionBuilder,
    $$MeetingRulesTableUpdateCompanionBuilder,
    (StoredMeetingRule, $$MeetingRulesTableReferences),
    StoredMeetingRule,
    PrefetchHooks Function({bool courseId})>;
typedef $$CourseExceptionsTableCreateCompanionBuilder
    = CourseExceptionsCompanion Function({
  required String id,
  required String semesterId,
  Value<String?> courseId,
  Value<String?> sourceMeetingId,
  Value<DateTime?> sourceDate,
  required String type,
  Value<DateTime?> targetDate,
  Value<int?> targetStartSection,
  Value<int?> targetEndSection,
  Value<String?> teacherOverride,
  Value<String?> campusOverride,
  Value<String?> roomOverride,
  Value<String?> addedCourseName,
  Value<String?> note,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$CourseExceptionsTableUpdateCompanionBuilder
    = CourseExceptionsCompanion Function({
  Value<String> id,
  Value<String> semesterId,
  Value<String?> courseId,
  Value<String?> sourceMeetingId,
  Value<DateTime?> sourceDate,
  Value<String> type,
  Value<DateTime?> targetDate,
  Value<int?> targetStartSection,
  Value<int?> targetEndSection,
  Value<String?> teacherOverride,
  Value<String?> campusOverride,
  Value<String?> roomOverride,
  Value<String?> addedCourseName,
  Value<String?> note,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$CourseExceptionsTableReferences extends BaseReferences<
    _$AppDatabase, $CourseExceptionsTable, CourseException> {
  $$CourseExceptionsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $SemestersTable _semesterIdTable(_$AppDatabase db) =>
      db.semesters.createAlias('course_exceptions__semester_id__semesters__id');

  $$SemestersTableProcessedTableManager get semesterId {
    final $_column = $_itemColumn<String>('semester_id')!;

    final manager = $$SemestersTableTableManager($_db, $_db.semesters)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_semesterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$CourseExceptionsTableFilterComposer
    extends Composer<_$AppDatabase, $CourseExceptionsTable> {
  $$CourseExceptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get courseId => $composableBuilder(
      column: $table.courseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceMeetingId => $composableBuilder(
      column: $table.sourceMeetingId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get sourceDate => $composableBuilder(
      column: $table.sourceDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get targetStartSection => $composableBuilder(
      column: $table.targetStartSection,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get targetEndSection => $composableBuilder(
      column: $table.targetEndSection,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get teacherOverride => $composableBuilder(
      column: $table.teacherOverride,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get campusOverride => $composableBuilder(
      column: $table.campusOverride,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get roomOverride => $composableBuilder(
      column: $table.roomOverride, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get addedCourseName => $composableBuilder(
      column: $table.addedCourseName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$SemestersTableFilterComposer get semesterId {
    final $$SemestersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.semesterId,
        referencedTable: $db.semesters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SemestersTableFilterComposer(
              $db: $db,
              $table: $db.semesters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CourseExceptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CourseExceptionsTable> {
  $$CourseExceptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get courseId => $composableBuilder(
      column: $table.courseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceMeetingId => $composableBuilder(
      column: $table.sourceMeetingId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get sourceDate => $composableBuilder(
      column: $table.sourceDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get targetStartSection => $composableBuilder(
      column: $table.targetStartSection,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get targetEndSection => $composableBuilder(
      column: $table.targetEndSection,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get teacherOverride => $composableBuilder(
      column: $table.teacherOverride,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get campusOverride => $composableBuilder(
      column: $table.campusOverride,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get roomOverride => $composableBuilder(
      column: $table.roomOverride,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get addedCourseName => $composableBuilder(
      column: $table.addedCourseName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$SemestersTableOrderingComposer get semesterId {
    final $$SemestersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.semesterId,
        referencedTable: $db.semesters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SemestersTableOrderingComposer(
              $db: $db,
              $table: $db.semesters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CourseExceptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CourseExceptionsTable> {
  $$CourseExceptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get sourceMeetingId => $composableBuilder(
      column: $table.sourceMeetingId, builder: (column) => column);

  GeneratedColumn<DateTime> get sourceDate => $composableBuilder(
      column: $table.sourceDate, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => column);

  GeneratedColumn<int> get targetStartSection => $composableBuilder(
      column: $table.targetStartSection, builder: (column) => column);

  GeneratedColumn<int> get targetEndSection => $composableBuilder(
      column: $table.targetEndSection, builder: (column) => column);

  GeneratedColumn<String> get teacherOverride => $composableBuilder(
      column: $table.teacherOverride, builder: (column) => column);

  GeneratedColumn<String> get campusOverride => $composableBuilder(
      column: $table.campusOverride, builder: (column) => column);

  GeneratedColumn<String> get roomOverride => $composableBuilder(
      column: $table.roomOverride, builder: (column) => column);

  GeneratedColumn<String> get addedCourseName => $composableBuilder(
      column: $table.addedCourseName, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SemestersTableAnnotationComposer get semesterId {
    final $$SemestersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.semesterId,
        referencedTable: $db.semesters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SemestersTableAnnotationComposer(
              $db: $db,
              $table: $db.semesters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CourseExceptionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CourseExceptionsTable,
    CourseException,
    $$CourseExceptionsTableFilterComposer,
    $$CourseExceptionsTableOrderingComposer,
    $$CourseExceptionsTableAnnotationComposer,
    $$CourseExceptionsTableCreateCompanionBuilder,
    $$CourseExceptionsTableUpdateCompanionBuilder,
    (CourseException, $$CourseExceptionsTableReferences),
    CourseException,
    PrefetchHooks Function({bool semesterId})> {
  $$CourseExceptionsTableTableManager(
      _$AppDatabase db, $CourseExceptionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CourseExceptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CourseExceptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CourseExceptionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> semesterId = const Value.absent(),
            Value<String?> courseId = const Value.absent(),
            Value<String?> sourceMeetingId = const Value.absent(),
            Value<DateTime?> sourceDate = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<DateTime?> targetDate = const Value.absent(),
            Value<int?> targetStartSection = const Value.absent(),
            Value<int?> targetEndSection = const Value.absent(),
            Value<String?> teacherOverride = const Value.absent(),
            Value<String?> campusOverride = const Value.absent(),
            Value<String?> roomOverride = const Value.absent(),
            Value<String?> addedCourseName = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CourseExceptionsCompanion(
            id: id,
            semesterId: semesterId,
            courseId: courseId,
            sourceMeetingId: sourceMeetingId,
            sourceDate: sourceDate,
            type: type,
            targetDate: targetDate,
            targetStartSection: targetStartSection,
            targetEndSection: targetEndSection,
            teacherOverride: teacherOverride,
            campusOverride: campusOverride,
            roomOverride: roomOverride,
            addedCourseName: addedCourseName,
            note: note,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String semesterId,
            Value<String?> courseId = const Value.absent(),
            Value<String?> sourceMeetingId = const Value.absent(),
            Value<DateTime?> sourceDate = const Value.absent(),
            required String type,
            Value<DateTime?> targetDate = const Value.absent(),
            Value<int?> targetStartSection = const Value.absent(),
            Value<int?> targetEndSection = const Value.absent(),
            Value<String?> teacherOverride = const Value.absent(),
            Value<String?> campusOverride = const Value.absent(),
            Value<String?> roomOverride = const Value.absent(),
            Value<String?> addedCourseName = const Value.absent(),
            Value<String?> note = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CourseExceptionsCompanion.insert(
            id: id,
            semesterId: semesterId,
            courseId: courseId,
            sourceMeetingId: sourceMeetingId,
            sourceDate: sourceDate,
            type: type,
            targetDate: targetDate,
            targetStartSection: targetStartSection,
            targetEndSection: targetEndSection,
            teacherOverride: teacherOverride,
            campusOverride: campusOverride,
            roomOverride: roomOverride,
            addedCourseName: addedCourseName,
            note: note,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CourseExceptionsTable, CourseException>(table),
                    $$CourseExceptionsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({semesterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (semesterId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.semesterId,
                    referencedTable:
                        $$CourseExceptionsTableReferences._semesterIdTable(db),
                    referencedColumn: $$CourseExceptionsTableReferences
                        ._semesterIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$CourseExceptionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CourseExceptionsTable,
    CourseException,
    $$CourseExceptionsTableFilterComposer,
    $$CourseExceptionsTableOrderingComposer,
    $$CourseExceptionsTableAnnotationComposer,
    $$CourseExceptionsTableCreateCompanionBuilder,
    $$CourseExceptionsTableUpdateCompanionBuilder,
    (CourseException, $$CourseExceptionsTableReferences),
    CourseException,
    PrefetchHooks Function({bool semesterId})>;
typedef $$ImportSnapshotsTableCreateCompanionBuilder = ImportSnapshotsCompanion
    Function({
  required String id,
  required String semesterId,
  required DateTime importedAt,
  required String adapterVersion,
  required int schemaVersion,
  required String normalizedJson,
  required String hash,
  Value<int> rowid,
});
typedef $$ImportSnapshotsTableUpdateCompanionBuilder = ImportSnapshotsCompanion
    Function({
  Value<String> id,
  Value<String> semesterId,
  Value<DateTime> importedAt,
  Value<String> adapterVersion,
  Value<int> schemaVersion,
  Value<String> normalizedJson,
  Value<String> hash,
  Value<int> rowid,
});

final class $$ImportSnapshotsTableReferences extends BaseReferences<
    _$AppDatabase, $ImportSnapshotsTable, ImportSnapshot> {
  $$ImportSnapshotsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $SemestersTable _semesterIdTable(_$AppDatabase db) =>
      db.semesters.createAlias('import_snapshots__semester_id__semesters__id');

  $$SemestersTableProcessedTableManager get semesterId {
    final $_column = $_itemColumn<String>('semester_id')!;

    final manager = $$SemestersTableTableManager($_db, $_db.semesters)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_semesterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ImportSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $ImportSnapshotsTable> {
  $$ImportSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
      column: $table.importedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get adapterVersion => $composableBuilder(
      column: $table.adapterVersion,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get schemaVersion => $composableBuilder(
      column: $table.schemaVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get normalizedJson => $composableBuilder(
      column: $table.normalizedJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hash => $composableBuilder(
      column: $table.hash, builder: (column) => ColumnFilters(column));

  $$SemestersTableFilterComposer get semesterId {
    final $$SemestersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.semesterId,
        referencedTable: $db.semesters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SemestersTableFilterComposer(
              $db: $db,
              $table: $db.semesters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ImportSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportSnapshotsTable> {
  $$ImportSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
      column: $table.importedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get adapterVersion => $composableBuilder(
      column: $table.adapterVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
      column: $table.schemaVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get normalizedJson => $composableBuilder(
      column: $table.normalizedJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hash => $composableBuilder(
      column: $table.hash, builder: (column) => ColumnOrderings(column));

  $$SemestersTableOrderingComposer get semesterId {
    final $$SemestersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.semesterId,
        referencedTable: $db.semesters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SemestersTableOrderingComposer(
              $db: $db,
              $table: $db.semesters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ImportSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportSnapshotsTable> {
  $$ImportSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
      column: $table.importedAt, builder: (column) => column);

  GeneratedColumn<String> get adapterVersion => $composableBuilder(
      column: $table.adapterVersion, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
      column: $table.schemaVersion, builder: (column) => column);

  GeneratedColumn<String> get normalizedJson => $composableBuilder(
      column: $table.normalizedJson, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  $$SemestersTableAnnotationComposer get semesterId {
    final $$SemestersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.semesterId,
        referencedTable: $db.semesters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SemestersTableAnnotationComposer(
              $db: $db,
              $table: $db.semesters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ImportSnapshotsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ImportSnapshotsTable,
    ImportSnapshot,
    $$ImportSnapshotsTableFilterComposer,
    $$ImportSnapshotsTableOrderingComposer,
    $$ImportSnapshotsTableAnnotationComposer,
    $$ImportSnapshotsTableCreateCompanionBuilder,
    $$ImportSnapshotsTableUpdateCompanionBuilder,
    (ImportSnapshot, $$ImportSnapshotsTableReferences),
    ImportSnapshot,
    PrefetchHooks Function({bool semesterId})> {
  $$ImportSnapshotsTableTableManager(
      _$AppDatabase db, $ImportSnapshotsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> semesterId = const Value.absent(),
            Value<DateTime> importedAt = const Value.absent(),
            Value<String> adapterVersion = const Value.absent(),
            Value<int> schemaVersion = const Value.absent(),
            Value<String> normalizedJson = const Value.absent(),
            Value<String> hash = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ImportSnapshotsCompanion(
            id: id,
            semesterId: semesterId,
            importedAt: importedAt,
            adapterVersion: adapterVersion,
            schemaVersion: schemaVersion,
            normalizedJson: normalizedJson,
            hash: hash,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String semesterId,
            required DateTime importedAt,
            required String adapterVersion,
            required int schemaVersion,
            required String normalizedJson,
            required String hash,
            Value<int> rowid = const Value.absent(),
          }) =>
              ImportSnapshotsCompanion.insert(
            id: id,
            semesterId: semesterId,
            importedAt: importedAt,
            adapterVersion: adapterVersion,
            schemaVersion: schemaVersion,
            normalizedJson: normalizedJson,
            hash: hash,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ImportSnapshotsTable, ImportSnapshot>(table),
                    $$ImportSnapshotsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({semesterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (semesterId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.semesterId,
                    referencedTable:
                        $$ImportSnapshotsTableReferences._semesterIdTable(db),
                    referencedColumn: $$ImportSnapshotsTableReferences
                        ._semesterIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ImportSnapshotsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ImportSnapshotsTable,
    ImportSnapshot,
    $$ImportSnapshotsTableFilterComposer,
    $$ImportSnapshotsTableOrderingComposer,
    $$ImportSnapshotsTableAnnotationComposer,
    $$ImportSnapshotsTableCreateCompanionBuilder,
    $$ImportSnapshotsTableUpdateCompanionBuilder,
    (ImportSnapshot, $$ImportSnapshotsTableReferences),
    ImportSnapshot,
    PrefetchHooks Function({bool semesterId})>;
typedef $$DeletedSourceItemsTableCreateCompanionBuilder
    = DeletedSourceItemsCompanion Function({
  required String id,
  required String semesterId,
  required String sourceCourseKey,
  Value<String?> sourceMeetingKey,
  required DateTime deletedAt,
  Value<int> rowid,
});
typedef $$DeletedSourceItemsTableUpdateCompanionBuilder
    = DeletedSourceItemsCompanion Function({
  Value<String> id,
  Value<String> semesterId,
  Value<String> sourceCourseKey,
  Value<String?> sourceMeetingKey,
  Value<DateTime> deletedAt,
  Value<int> rowid,
});

final class $$DeletedSourceItemsTableReferences extends BaseReferences<
    _$AppDatabase, $DeletedSourceItemsTable, DeletedSourceItem> {
  $$DeletedSourceItemsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $SemestersTable _semesterIdTable(_$AppDatabase db) => db.semesters
      .createAlias('deleted_source_items__semester_id__semesters__id');

  $$SemestersTableProcessedTableManager get semesterId {
    final $_column = $_itemColumn<String>('semester_id')!;

    final manager = $$SemestersTableTableManager($_db, $_db.semesters)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_semesterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$DeletedSourceItemsTableFilterComposer
    extends Composer<_$AppDatabase, $DeletedSourceItemsTable> {
  $$DeletedSourceItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceCourseKey => $composableBuilder(
      column: $table.sourceCourseKey,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceMeetingKey => $composableBuilder(
      column: $table.sourceMeetingKey,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  $$SemestersTableFilterComposer get semesterId {
    final $$SemestersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.semesterId,
        referencedTable: $db.semesters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SemestersTableFilterComposer(
              $db: $db,
              $table: $db.semesters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DeletedSourceItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $DeletedSourceItemsTable> {
  $$DeletedSourceItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceCourseKey => $composableBuilder(
      column: $table.sourceCourseKey,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceMeetingKey => $composableBuilder(
      column: $table.sourceMeetingKey,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  $$SemestersTableOrderingComposer get semesterId {
    final $$SemestersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.semesterId,
        referencedTable: $db.semesters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SemestersTableOrderingComposer(
              $db: $db,
              $table: $db.semesters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DeletedSourceItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeletedSourceItemsTable> {
  $$DeletedSourceItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceCourseKey => $composableBuilder(
      column: $table.sourceCourseKey, builder: (column) => column);

  GeneratedColumn<String> get sourceMeetingKey => $composableBuilder(
      column: $table.sourceMeetingKey, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$SemestersTableAnnotationComposer get semesterId {
    final $$SemestersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.semesterId,
        referencedTable: $db.semesters,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SemestersTableAnnotationComposer(
              $db: $db,
              $table: $db.semesters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DeletedSourceItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DeletedSourceItemsTable,
    DeletedSourceItem,
    $$DeletedSourceItemsTableFilterComposer,
    $$DeletedSourceItemsTableOrderingComposer,
    $$DeletedSourceItemsTableAnnotationComposer,
    $$DeletedSourceItemsTableCreateCompanionBuilder,
    $$DeletedSourceItemsTableUpdateCompanionBuilder,
    (DeletedSourceItem, $$DeletedSourceItemsTableReferences),
    DeletedSourceItem,
    PrefetchHooks Function({bool semesterId})> {
  $$DeletedSourceItemsTableTableManager(
      _$AppDatabase db, $DeletedSourceItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeletedSourceItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeletedSourceItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeletedSourceItemsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> semesterId = const Value.absent(),
            Value<String> sourceCourseKey = const Value.absent(),
            Value<String?> sourceMeetingKey = const Value.absent(),
            Value<DateTime> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DeletedSourceItemsCompanion(
            id: id,
            semesterId: semesterId,
            sourceCourseKey: sourceCourseKey,
            sourceMeetingKey: sourceMeetingKey,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String semesterId,
            required String sourceCourseKey,
            Value<String?> sourceMeetingKey = const Value.absent(),
            required DateTime deletedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DeletedSourceItemsCompanion.insert(
            id: id,
            semesterId: semesterId,
            sourceCourseKey: sourceCourseKey,
            sourceMeetingKey: sourceMeetingKey,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$DeletedSourceItemsTable, DeletedSourceItem>(
                        table),
                    $$DeletedSourceItemsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({semesterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (semesterId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.semesterId,
                    referencedTable: $$DeletedSourceItemsTableReferences
                        ._semesterIdTable(db),
                    referencedColumn: $$DeletedSourceItemsTableReferences
                        ._semesterIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$DeletedSourceItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DeletedSourceItemsTable,
    DeletedSourceItem,
    $$DeletedSourceItemsTableFilterComposer,
    $$DeletedSourceItemsTableOrderingComposer,
    $$DeletedSourceItemsTableAnnotationComposer,
    $$DeletedSourceItemsTableCreateCompanionBuilder,
    $$DeletedSourceItemsTableUpdateCompanionBuilder,
    (DeletedSourceItem, $$DeletedSourceItemsTableReferences),
    DeletedSourceItem,
    PrefetchHooks Function({bool semesterId})>;
typedef $$AppSettingsTableCreateCompanionBuilder = AppSettingsCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppSettingsTableUpdateCompanionBuilder = AppSettingsCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()> {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$AppSettingsTable, AppSetting>(table),
                    BaseReferences<_$AppDatabase, $AppSettingsTable,
                        AppSetting>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SemestersTableTableManager get semesters =>
      $$SemestersTableTableManager(_db, _db.semesters);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db, _db.courses);
  $$MeetingRulesTableTableManager get meetingRules =>
      $$MeetingRulesTableTableManager(_db, _db.meetingRules);
  $$CourseExceptionsTableTableManager get courseExceptions =>
      $$CourseExceptionsTableTableManager(_db, _db.courseExceptions);
  $$ImportSnapshotsTableTableManager get importSnapshots =>
      $$ImportSnapshotsTableTableManager(_db, _db.importSnapshots);
  $$DeletedSourceItemsTableTableManager get deletedSourceItems =>
      $$DeletedSourceItemsTableTableManager(_db, _db.deletedSourceItems);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
