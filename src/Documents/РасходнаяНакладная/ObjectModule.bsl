
Процедура ОбработкаПроведения(Отказ, Режим)

	//Прочитаем Учетную политику
	СпособСписанияСебестоимости = РегистрыСведений.УчетнаяПолитика.ПолучитьПоследнее(МоментВремени()).СпособСписанияСебестоимости;
	
	Запрос = Новый Запрос;
	Запрос.МенеджерВременныхТаблиц = Новый МенеджерВременныхТаблиц; //ВТ ТоварыДокумента будем использовать не в одном запросе
	
	Запрос.Текст = "ВЫБРАТЬ
	               |	РасходнаяНакладнаяТовары.Номенклатура КАК Номенклатура,
	               |	СУММА(РасходнаяНакладнаяТовары.Количество) КАК Количество,
	               |	СУММА(РасходнаяНакладнаяТовары.Сумма) КАК Сумма
	               |ПОМЕСТИТЬ ВсеПозицииДокумента
	               |ИЗ
	               |	Документ.РасходнаяНакладная.Товары КАК РасходнаяНакладнаяТовары
	               |ГДЕ
	               |	РасходнаяНакладнаяТовары.Ссылка = &Ссылка
	               |
	               |СГРУППИРОВАТЬ ПО
	               |	РасходнаяНакладнаяТовары.Номенклатура
	               |
	               |ИНДЕКСИРОВАТЬ ПО
	               |	Номенклатура
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
				   |ВЫБРАТЬ
	               |	ВсеПозицииДокумента.Номенклатура КАК Номенклатура,
	               |	ВсеПозицииДокумента.Количество КАК Количество
	               |ПОМЕСТИТЬ ТоварыДокумента
	               |ИЗ
	               |	ВсеПозицииДокумента КАК ВсеПозицииДокумента
	               |ГДЕ
	               |	ВсеПозицииДокумента.Номенклатура.Вид = ЗНАЧЕНИЕ(Перечисление.ВидНоменклатуры.Товар)
	               |
	               |ИНДЕКСИРОВАТЬ ПО
	               |	Номенклатура
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |ВЫБРАТЬ
	               |	&Дата КАК Период,
	               |	ЗНАЧЕНИЕ(ВидДвиженияНакопления.Расход) КАК ВидДвижения,
	               |	ТоварыДокумента.Номенклатура КАК Номенклатура,
	               |	ТоварыДокумента.Количество КАК Количество
	               |ИЗ
	               |	ТоварыДокумента КАК ТоварыДокумента";
	Запрос.УстановитьПараметр("Ссылка", Ссылка);
	Запрос.УстановитьПараметр("Дата", Дата);
	Результат = Запрос.Выполнить();
	
	//Загружаем готовые движения
	Движения.ОстаткиНоменклатуры.Загрузить(Результат.Выгрузить());
	Движения.ОстаткиНоменклатуры.БлокироватьДляИзменения = Истина;
	Движения.ОстаткиНоменклатуры.Записывать = Истина;
	Движения.Записать();
	
	
	//проверяем на минусы
	Запрос.Текст = "ВЫБРАТЬ
	               |	ОстаткиНоменклатурыОстатки.Номенклатура КАК Номенклатура,
	               |	ОстаткиНоменклатурыОстатки.КоличествоОстаток КАК Минус
	               |ИЗ
	               |	РегистрНакопления.ОстаткиНоменклатуры.Остатки(
	               |			&МоментВремени,
	               |			Номенклатура В
	               |				(ВЫБРАТЬ
	               |					ТоварыДокумента.Номенклатура КАК Номенклатура
	               |				ИЗ
	               |					ТоварыДокумента КАК ТоварыДокумента)) КАК ОстаткиНоменклатурыОстатки
	               |ГДЕ
	               |	ОстаткиНоменклатурыОстатки.КоличествоОстаток < 0";
	//Если Оперативно то актуальные итоги, усли нет то включая движения документа
	МоментКонтроляОстатков = ?(Режим = РежимПроведенияДокумента.Оперативный, Неопределено, Новый Граница(МоментВремени(), ВидГраницы.Включая));
	Запрос.УстановитьПараметр("МоментВремени", МоментКонтроляОстатков);
	Результат = Запрос.Выполнить();
	
	Если НЕ Результат.Пустой() Тогда
		Отказ = Истина;
		Выборка = Результат.Выбрать();
		Пока Выборка.Следующий() Цикл
			Сообщение = Новый СообщениеПользователю;
			Сообщение.Текст = СтрШаблон("Недостаточно товара - %1 в количестве - %2", Выборка.Номенклатура, -Выборка.Минус);
			Сообщение.УстановитьДанные(ЭтотОбъект);
			Сообщение.Сообщить();
		КонецЦикла;
	КонецЕсли;
	
	//Если не хватает опер. остатков, то движения по остальным регистрам не делаем
	Если Отказ Тогда
		Возврат;
	КонецЕсли;
	
	//Себестоимость
	//Чистим
	Если Режим = РежимПроведенияДокумента.Оперативный Тогда
		Движения.ПартииНоменклатуры.Записывать = Истина;
		//Так как движения в регистры "ОстаткиНоменклатуры" и "ПартииНоменклатуры" выполняются всегда синхроннои последовательно,
		//сдесь и далее Управляемую блокировку на регистр "Партии" не накладываем. будет излишней
		Движения.Записать();
	КонецЕсли;
	Движения.ПартииНоменклатуры.Записывать = Истина;
	
	Запрос.Текст = "ВЫБРАТЬ
	               |	ТоварыДокумента.Номенклатура КАК Номенклатура,
	               |	ТоварыДокумента.Количество КАК Количество,
	               |	ЕСТЬNULL(ПартииНоменклатурыОстатки.КоличествоОстаток, 0) КАК КоличествоОстаток,
	               |	ЕСТЬNULL(ПартииНоменклатурыОстатки.СтоимостьОстаток, 0) КАК СтоимостьОстаток,
	               |	ПартииНоменклатурыОстатки.Партия КАК Партия
	               |ИЗ
	               |	ТоварыДокумента КАК ТоварыДокумента
	               |		ЛЕВОЕ СОЕДИНЕНИЕ РегистрНакопления.ПартииНоменклатуры.Остатки(
	               |				&МоментВремени,
	               |				Номенклатура В
	               |					(ВЫБРАТЬ
	               |						Товары.Номенклатура КАК Номенклатура
	               |					ИЗ
	               |						ТоварыДокумента КАК Товары)) КАК ПартииНоменклатурыОстатки
	               |		ПО ТоварыДокумента.Номенклатура = ПартииНоменклатурыОстатки.Номенклатура
	               |
	               |УПОРЯДОЧИТЬ ПО
	               |	ПартииНоменклатурыОстатки.Партия.МоментВремени" + ?(СпособСписанияСебестоимости = Перечисления.СпособСписанияСебестоимости.ЛИФО, " УБЫВ", "") + " 
				   |ИТОГИ
	               |	МАКСИМУМ(Количество),
	               |	СУММА(КоличествоОстаток)
	               |ПО
	               |	Номенклатура";
	Запрос.УстановитьПараметр("МоментВремени", МоментКонтроляОстатков);
	РезультатЗапроса = Запрос.Выполнить();
	
	ВыборкаПоНоменклатуре = РезультатЗапроса.Выбрать(ОбходРезультатаЗапроса.ПоГруппировкам);
	Пока ВыборкаПоНоменклатуре.Следующий() Цикл
		ОсталосьСписать = ВыборкаПоНоменклатуре.Количество;
		ВыборкаПоПартии  = ВыборкаПоНоменклатуре.Выбрать();
		Пока ВыборкаПоПартии.Следующий() И ОсталосьСписать > 0 Цикл
			ОстатокПоПартии = ВыборкаПоПартии.КоличествоОстаток;
			Если ОстатокПоПартии = 0 Тогда
				Продолжить;
			КонецЕсли;
			Движение = Движения.ПартииНоменклатуры.ДобавитьРасход();
			Движение.Период = Дата;
			Движение.Номенклатура  = ВыборкаПоПартии.Номенклатура;
			Движение.Партия = ВыборкаПоПартии.Партия;
			Движение.Количество   = Мин(ОсталосьСписать, ОстатокПоПартии);
			Движение.Стоимость  = Движение.Количество * ВыборкаПоПартии.СтоимостьОстаток / ОстатокПоПартии;
			ОсталосьСписать = ОсталосьСписать - Движение.Количество;
		КонецЦикла;
		Если ОсталосьСписать > 0 Тогда
			Сообщить(СтрШаблон("Не списано по партиям %1 штук товара - ""%2""", ОсталосьСписать, ВыборкаПоПартии.Номенклатура));
		КонецЕсли; 
	КонецЦикла;
	
	//Продажи
	//Себестоимость берем готовую из движений по партиям
	ТаблицаСебестоимости = Движения.ПартииНоменклатуры.Выгрузить(, "Номенклатура, Стоимость");
	ТаблицаСебестоимости.Индексы.Добавить("Номенклатура");
	ТаблицаСебестоимости.Свернуть("Номенклатура", "Стоимость");
	Запрос.Текст = "ВЫБРАТЬ
	               |	ТаблицаСебестоимости.Номенклатура КАК Номенклатура,
	               |	ТаблицаСебестоимости.Стоимость КАК Себестоимость
	               |ПОМЕСТИТЬ ТаблицаСебестоимости
	               |ИЗ
	               |	&ТаблицаСебестоимости КАК ТаблицаСебестоимости
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |ВЫБРАТЬ
	               |	&Дата КАК Период,
	               |	ВсеПозицииДокумента.Номенклатура КАК Номенклатура,
	               |	ВсеПозицииДокумента.Количество КАК Количество,
	               |	ВсеПозицииДокумента.Сумма КАК Сумма,
	               |	ЕСТЬNULL(ТаблицаСебестоимости.Себестоимость, 0) КАК Себестоимость
	               |ИЗ
	               |	ВсеПозицииДокумента КАК ВсеПозицииДокумента
	               |		ЛЕВОЕ СОЕДИНЕНИЕ ТаблицаСебестоимости КАК ТаблицаСебестоимости
	               |		ПО ВсеПозицииДокумента.Номенклатура = ТаблицаСебестоимости.Номенклатура";
	
	Запрос.УстановитьПараметр("Дата", Дата);
	Запрос.УстановитьПараметр("ТаблицаСебестоимости", ТаблицаСебестоимости);
	
	Результат = Запрос.Выполнить();
	
	//Загружаем готовые движения
	Движения.Продажи.Загрузить(Результат.Выгрузить());
	Движения.Продажи.Записывать = Истина;
	
КонецПроцедуры
