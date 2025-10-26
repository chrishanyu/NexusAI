//
//  ConversationActionItemsSheet.swift
//  NexusAI
//
//  Created on October 26, 2025.
//

import SwiftUI

/// Full-screen sheet displaying action items for a conversation
struct ConversationActionItemsSheet: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: ActionItemViewModel
    @Binding var isPresented: Bool
    
    @State private var showCompletedSection = true
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main content
                contentView
                
                // Loading overlay
                if viewModel.isLoading {
                    loadingOverlay
                }
                
                // Success toast
                if viewModel.showSuccessToast, let message = viewModel.successMessage {
                    successToast(message: message)
                }
            }
            .navigationTitle("Action Items (\(viewModel.incompleteCount))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.extractItems()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Extract")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("Try Again") {
                    Task {
                        await viewModel.extractItems()
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Main content view
    private var contentView: some View {
        Group {
            if viewModel.items.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                actionItemsList
            }
        }
    }
    
    /// Empty state view
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("No action items yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap Extract to analyze this conversation.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    /// List of action items
    private var actionItemsList: some View {
        List {
            // Incomplete section (always visible)
            if !viewModel.incompleteItems.isEmpty {
                Section {
                    ForEach(viewModel.incompleteItems) { item in
                        ActionItemRow(
                            item: item,
                            onToggleComplete: {
                                Task {
                                    await viewModel.toggleComplete(item.id)
                                }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Incomplete")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .textCase(nil)
                }
            }
            
            // Completed section (collapsible)
            if !viewModel.completedItems.isEmpty {
                Section {
                    DisclosureGroup(
                        isExpanded: $showCompletedSection,
                        content: {
                            ForEach(viewModel.completedItems) { item in
                                ActionItemRow(
                                    item: item,
                                    onToggleComplete: {
                                        Task {
                                            await viewModel.toggleComplete(item.id)
                                        }
                                    }
                                )
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        },
                        label: {
                            HStack {
                                Text("Completed")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Text("\(viewModel.completedItems.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
                }
            }
        }
        .listStyle(.plain)
    }
    
    /// Loading overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.3)
                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                
                Text("Analyzing conversation...")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
        }
    }
    
    /// Success toast notification
    private func successToast(message: String) -> some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20))
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        viewModel.showSuccessToast = false
                    }
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.showSuccessToast)
    }
}

// MARK: - Preview

#Preview {
    // Preview requires ActionItemViewModel which will be created in Task 6.0
    // For now, we'll add a basic preview structure
    Text("ConversationActionItemsSheet Preview")
        .font(.title)
}

