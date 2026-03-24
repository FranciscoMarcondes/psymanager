import SwiftUI
import SwiftData

private let expenseCategories = [
    "Equipamento",
    "Transporte",
    "Marketing",
    "Produção musical",
    "Alimentação",
    "Hospedagem",
    "Software / Assinatura",
    "Cachê pago (DJ convidado)",
    "Outro",
]

private let categoryIcon: [String: String] = [
    "Equipamento": "🎛",
    "Transporte": "🚗",
    "Marketing": "📣",
    "Produção musical": "🎵",
    "Alimentação": "🍔",
    "Hospedagem": "🏨",
    "Software / Assinatura": "💻",
    "Cachê pago (DJ convidado)": "🎤",
    "Outro": "📦",
]

private func fmtBRL(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "BRL"
    f.locale = Locale(identifier: "pt_BR")
    return f.string(from: NSNumber(value: value)) ?? "R$ 0,00"
}

struct FinancesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.dateISO, order: .reverse) private var expenses: [Expense]
    @Query(sort: \Gig.date, order: .reverse) private var gigs: [Gig]

    @State private var selectedTab = 0
    @State private var showingExpenseForm = false
    @State private var appeared = false

    // Break-even calculator state
    @State private var beGrossFee = ""
    @State private var beAgencyPct = "15"
    @State private var beTaxPct = "8"
    @State private var beFlight = ""
    @State private var beHotel = ""
    @State private var beTransport = ""
    @State private var beFood = ""
    @State private var beOther = ""

    // Expense filter
    @State private var filterCategory = ""
    @State private var filterMonth = ""

    private var gigRevenue: Double {
        gigs.reduce(0) { $0 + $1.fee }
    }

    private var totalExpenses: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    private var netBalance: Double { gigRevenue - totalExpenses }

    private var healthPct: Int {
        guard gigRevenue > 0 else { return 0 }
        return min(100, max(0, Int((netBalance / gigRevenue) * 100)))
    }

    private var healthColor: Color {
        healthPct >= 60 ? .green : healthPct >= 30 ? .orange : .red
    }

    private var healthLabel: String {
        healthPct >= 60 ? "Saudável" : healthPct >= 30 ? "Atenção" : "Crítico"
    }

    private var byCategory: [(cat: String, total: Double)] {
        expenseCategories.compactMap { cat -> (String, Double)? in
            let total = expenses.filter { $0.category == cat }.reduce(0) { $0 + $1.amount }
            return total > 0 ? (cat, total) : nil
        }.sorted { $0.1 > $1.1 }
    }

    private var filteredExpenses: [Expense] {
        expenses.filter { e in
            (filterCategory.isEmpty || e.category == filterCategory) &&
            (filterMonth.isEmpty || e.dateISO.hasPrefix(filterMonth))
        }
    }

    // Break-even computed values
    private var beGross: Double { Double(beGrossFee.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var beAgencyValue: Double { beGross * ((Double(beAgencyPct) ?? 0) / 100) }
    private var beTaxValue: Double { beGross * ((Double(beTaxPct) ?? 0) / 100) }
    private var beOperational: Double {
        let flight = Double(beFlight.replacingOccurrences(of: ",", with: ".")) ?? 0
        let hotel = Double(beHotel.replacingOccurrences(of: ",", with: ".")) ?? 0
        let transport = Double(beTransport.replacingOccurrences(of: ",", with: ".")) ?? 0
        let food = Double(beFood.replacingOccurrences(of: ",", with: ".")) ?? 0
        let other = Double(beOther.replacingOccurrences(of: ",", with: ".")) ?? 0
        return flight + hotel + transport + food + other
    }
    private var beNet: Double { beGross - beAgencyValue - beTaxValue - beOperational }
    private var beMarginPct: Int { beGross > 0 ? Int((beNet / beGross) * 100) : 0 }
    private var beStatus: String {
        guard beGross > 0 else { return "" }
        if beNet > 0 { return "Lucro" }
        if beNet == 0 { return "Break-even" }
        return "Prejuízo"
    }

    // Monthly trend (last 6 months)
    private var monthlyTrend: [(month: String, income: Double, expense: Double)] {
        var incomeMap: [String: Double] = [:]
        var expenseMap: [String: Double] = [:]
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "yyyy-MM"
        for gig in gigs {
            let m = df.string(from: gig.date)
            incomeMap[m, default: 0] += gig.fee
        }
        for exp in expenses {
            let m = String(exp.dateISO.prefix(7))
            expenseMap[m, default: 0] += exp.amount
        }
        let allMonths = Array(Set(incomeMap.keys).union(expenseMap.keys)).sorted().suffix(6)
        return allMonths.map { m in
            (month: m, income: incomeMap[m] ?? 0, expense: expenseMap[m] ?? 0)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    PsyHeroCard {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                                .font(.title)
                                .foregroundStyle(PsyTheme.primary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Finanças")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                Text("Controle de receitas, gastos e break-even.")
                                    .font(.caption)
                                    .foregroundStyle(PsyTheme.textSecondary)
                            }
                            Spacer()
                        }
                    }
                    .psyAppear(delay: 0)

                    // Sub-tab picker
                    Picker("Seção", selection: $selectedTab) {
                        Text("Geral").tag(0)
                        Text("Gastos (\(expenses.count))").tag(1)
                        Text("Receitas").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 2)
                    .psyAppear(delay: 0.06)

                    if selectedTab == 0 {
                        overviewSection
                    } else if selectedTab == 1 {
                        expensesSection
                    } else {
                        incomeSection
                    }
                }
                .padding(20)
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Finanças")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            .sensoryFeedback(.selection, trigger: selectedTab)
            .toolbar {
                if selectedTab == 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("+ Gasto") { showingExpenseForm = true }
                    }
                }
            }
            .sheet(isPresented: $showingExpenseForm) {
                ExpenseFormView { expense in
                    modelContext.insert(expense)
                    try? modelContext.save()
                }
            }
        }
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(spacing: 16) {
            // KPI row
            HStack(spacing: 12) {
                kpiCard(title: "Receita", value: fmtBRL(gigRevenue), color: .green)
                kpiCard(title: "Gastos", value: fmtBRL(totalExpenses), color: .red)
                kpiCard(title: "Saldo", value: fmtBRL(netBalance), color: netBalance >= 0 ? .green : .red)
            }
            .psyAppear(delay: 0.10)

            // Health meter
            PsyCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Saúde financeira")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(healthLabel)
                            .font(.caption.bold())
                            .foregroundStyle(healthColor)
                    }
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(healthColor)
                                    .frame(width: geo.size.width * CGFloat(healthPct) / 100)
                            }
                    }
                    .frame(height: 10)
                    Text(gigRevenue == 0
                         ? "Registre gigs com fee para calcular saúde financeira."
                         : "\(healthPct)% da receita é saldo líquido após gastos registrados.")
                        .font(.caption)
                        .foregroundStyle(PsyTheme.textSecondary)
                }
            }
            .psyAppear(delay: 0.14)

            // Break-even calculator
            PsyCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "function")
                            .foregroundStyle(PsyTheme.primary)
                        Text("Break-even de gig")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    Text("Simule o lucro real antes de fechar: comissão, impostos, voo, hotel e custos operacionais.")
                        .font(.caption)
                        .foregroundStyle(PsyTheme.textSecondary)

                    VStack(spacing: 10) {
                        beField("Cachê bruto (R$)", text: $beGrossFee, placeholder: "Ex: 3500")
                        HStack(spacing: 10) {
                            beField("Agência (%)", text: $beAgencyPct)
                            beField("Impostos (%)", text: $beTaxPct)
                        }
                        HStack(spacing: 10) {
                            beField("Voo (R$)", text: $beFlight)
                            beField("Hotel (R$)", text: $beHotel)
                        }
                        HStack(spacing: 10) {
                            beField("Transfer (R$)", text: $beTransport)
                            beField("Alimentação (R$)", text: $beFood)
                        }
                        beField("Outros custos (R$)", text: $beOther)
                    }

                    if beGross > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            Divider().overlay(Color.white.opacity(0.1))
                            Text("Comissão: \(fmtBRL(beAgencyValue))  •  Impostos: \(fmtBRL(beTaxValue))  •  Operacional: \(fmtBRL(beOperational))")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                            HStack {
                                Text("\(beStatus):")
                                    .font(.headline)
                                    .foregroundStyle(beNet >= 0 ? Color.green : Color.red)
                                Text(fmtBRL(beNet))
                                    .font(.headline)
                                    .foregroundStyle(beNet >= 0 ? Color.green : Color.red)
                                Text("(\(beMarginPct)%)")
                                    .font(.subheadline)
                                    .foregroundStyle(PsyTheme.textSecondary)
                            }
                        }
                    } else {
                        Text("Informe o cachê bruto para calcular.")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                }
            }
            .psyAppear(delay: 0.18)

            // Category breakdown
            if !byCategory.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    PsySectionHeader(eyebrow: "Breakdown", title: "Gastos por categoria")
                    PsyCard {
                        VStack(spacing: 8) {
                            ForEach(byCategory, id: \.cat) { item in
                                HStack {
                                    Text(categoryIcon[item.cat] ?? "📦")
                                    Text(item.cat)
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(fmtBRL(item.total))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.red)
                                    if gigRevenue > 0 {
                                        Text("\(Int((item.total / gigRevenue) * 100))%")
                                            .font(.caption)
                                            .foregroundStyle(PsyTheme.textSecondary)
                                            .frame(minWidth: 32, alignment: .trailing)
                                    }
                                }
                            }
                        }
                    }
                }
                .psyAppear(delay: 0.22)
            }

            // Monthly trend
            if !monthlyTrend.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    PsySectionHeader(eyebrow: "Últimos 6 meses", title: "Tendência mensal")
                    PsyCard {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Mês").frame(minWidth: 60, alignment: .leading)
                                Spacer()
                                Text("Receita").foregroundStyle(.green)
                                    .frame(minWidth: 80, alignment: .trailing)
                                Text("Gastos").foregroundStyle(.red)
                                    .frame(minWidth: 80, alignment: .trailing)
                                Text("Saldo").frame(minWidth: 80, alignment: .trailing)
                            }
                            .font(.caption.bold())
                            .padding(.bottom, 6)
                            Divider().overlay(Color.white.opacity(0.1))

                            ForEach(monthlyTrend, id: \.month) { row in
                                HStack {
                                    Text(monthLabel(row.month))
                                        .frame(minWidth: 60, alignment: .leading)
                                    Spacer()
                                    Text(row.income > 0 ? fmtBRL(row.income) : "—")
                                        .foregroundStyle(.green)
                                        .frame(minWidth: 80, alignment: .trailing)
                                    Text(row.expense > 0 ? fmtBRL(row.expense) : "—")
                                        .foregroundStyle(.red)
                                        .frame(minWidth: 80, alignment: .trailing)
                                    let bal = row.income - row.expense
                                    Text(fmtBRL(bal))
                                        .foregroundStyle(bal >= 0 ? .green : .red)
                                        .frame(minWidth: 80, alignment: .trailing)
                                }
                                .font(.caption)
                                .padding(.vertical, 5)
                                Divider().overlay(Color.white.opacity(0.06))
                            }
                        }
                    }
                }
                .psyAppear(delay: 0.26)
            }
        }
    }

    // MARK: - Expenses

    private var expensesSection: some View {
        VStack(spacing: 16) {
            // Filter row
            PsyCard {
                VStack(spacing: 10) {
                    Picker("Categoria", selection: $filterCategory) {
                        Text("Todas categorias").tag("")
                        ForEach(expenseCategories, id: \.self) { cat in
                            Text("\(categoryIcon[cat] ?? "") \(cat)").tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(PsyTheme.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .psyAppear(delay: 0.06)

            if filteredExpenses.isEmpty {
                PsyEmptyStateCard(title: "Sem gastos registrados", subtitle: "Toque em \"+ Gasto\" para adicionar.")
                    .psyAppear(delay: 0.1)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredExpenses, id: \.persistentModelID) { expense in
                        PsyCard {
                            HStack(alignment: .top, spacing: 12) {
                                Text(categoryIcon[expense.category] ?? "📦")
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(expense.descriptionText)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                    Text("\(expense.category) · \(expense.dateISO)")
                                        .font(.caption)
                                        .foregroundStyle(PsyTheme.textSecondary)
                                    if !expense.notes.isEmpty {
                                        Text(expense.notes)
                                            .font(.caption)
                                            .foregroundStyle(PsyTheme.textSecondary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 6) {
                                    Text(fmtBRL(expense.amount))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.red)
                                    Button(role: .destructive) {
                                        modelContext.delete(expense)
                                        try? modelContext.save()
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                    }
                                    .tint(.red.opacity(0.7))
                                }
                            }
                        }
                    }
                    // Total
                    HStack {
                        Spacer()
                        Text("Total: \(fmtBRL(filteredExpenses.reduce(0) { $0 + $1.amount }))")
                            .font(.subheadline.bold())
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 4)
                }
                .psyAppear(delay: 0.10)
            }
        }
    }

    // MARK: - Income

    private var incomeSection: some View {
        VStack(spacing: 16) {
            PsyCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Receitas — Gigs registradas")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Receitas são calculadas automaticamente pelas gigs com fee registrado no módulo de Eventos.")
                        .font(.caption)
                        .foregroundStyle(PsyTheme.textSecondary)
                }
            }
            .psyAppear(delay: 0.06)

            let gigsWithFee = gigs.filter { $0.fee > 0 }
            if gigsWithFee.isEmpty {
                PsyEmptyStateCard(title: "Sem gigs com fee", subtitle: "Adicione gigs no módulo de Eventos.")
                    .psyAppear(delay: 0.10)
            } else {
                VStack(spacing: 10) {
                    ForEach(gigsWithFee, id: \.persistentModelID) { gig in
                        PsyCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(gig.title)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                    Text("\(gig.city) · \(gig.state)")
                                        .font(.caption)
                                        .foregroundStyle(PsyTheme.textSecondary)
                                    Text(gig.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(PsyTheme.textSecondary)
                                }
                                Spacer()
                                Text(fmtBRL(gig.fee))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    HStack {
                        Spacer()
                        Text("Total: \(fmtBRL(gigRevenue))")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 4)
                }
                .psyAppear(delay: 0.10)
            }
        }
    }

    // MARK: - Helpers

    private func kpiCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(PsyTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(PsyTheme.surfaceAlt.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func beField(_ label: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(PsyTheme.textSecondary)
            TextField(placeholder.isEmpty ? label : placeholder, text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .colorScheme(.dark)
        }
    }

    private func monthLabel(_ iso: String) -> String {
        let parts = iso.split(separator: "-")
        guard parts.count == 2,
              let yr = Int(parts[0]),
              let mo = Int(parts[1]) else { return iso }
        let d = Calendar.current.date(from: DateComponents(year: yr, month: mo)) ?? Date()
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "MMM/yy"
        return df.string(from: d).capitalized
    }
}

// MARK: - Expense Form

private struct ExpenseFormView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Expense) -> Void

    @State private var descriptionText = ""
    @State private var amount = ""
    @State private var category = "Equipamento"
    @State private var notes = ""
    @State private var dateISO: String = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }()

    private var parsedAmount: Double {
        Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PsyHeroCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Registrar gasto")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("Categorize este gasto para acompanhar a saúde financeira.")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }

                    PsyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Descrição *", text: $descriptionText)
                                .textFieldStyle(.roundedBorder)
                            TextField("Valor (R$) *", text: $amount)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)

                            Picker("Categoria", selection: $category) {
                                ForEach(expenseCategories, id: \.self) { cat in
                                    Text("\(categoryIcon[cat] ?? "") \(cat)").tag(cat)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(PsyTheme.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            DatePicker(
                                "Data",
                                selection: Binding(
                                    get: {
                                        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
                                        return df.date(from: dateISO) ?? Date()
                                    },
                                    set: { newDate in
                                        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
                                        dateISO = df.string(from: newDate)
                                    }
                                ),
                                displayedComponents: [.date]
                            )
                            .tint(PsyTheme.primary)

                            TextField("Observações (opcional)", text: $notes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...4)
                        }
                    }
                }
                .padding(20)
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Novo gasto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(Expense(
                            dateISO: dateISO,
                            descriptionText: descriptionText.trimmingCharacters(in: .whitespaces),
                            amount: parsedAmount,
                            category: category,
                            notes: notes.trimmingCharacters(in: .whitespaces)
                        ))
                        dismiss()
                    }
                    .disabled(descriptionText.trimmingCharacters(in: .whitespaces).isEmpty || parsedAmount <= 0)
                }
            }
        }
    }
}
