//
//  ContentView.swift
//  pointcard
//
//  Created by Samin Kandel on 2025/10/09.
//

// ファイル冒頭の import 群の下に追加
import UIKit
import SwiftUI
import AVFoundation
import CoreImage.CIFilterBuiltins



// Theme colors (White text on Warm Brown background)
extension Color {
    // Accent white for text and icons
    static let themeAccent   = Color.white
    // Softer warm brown background (#6B3E1E)
    static let themeBrown    = Color(red: 0.42, green: 0.24, blue: 0.12)
    // Secondary text slightly grayish white
    static let themeSubText = Color(red: 0.95, green: 0.95, blue: 0.95)
}

struct ContentView: View {
    // 永続化: アプリを閉じても保持されます
    @AppStorage("stamps") private var stamps: Int = 0
    @AppStorage("rewardsRedeemed") private var rewardsRedeemed: Int = 0
    @AppStorage("customerID") private var customerID: String = UUID().uuidString
    
    private let maxStamps: Int = 10
    
    // 店員用設定（デモ値）
    private let yenPerPoint: Int = 500      // 500円で1スタンプ
    private let staffPIN: String = "1234"  // 店員用PIN（デモ）
    
    // 店員モード用の状態
    @State private var showStaffSheet = false
    @State private var staffPINInput: String = ""
    @State private var saleAmount: Int? = nil
    @State private var staffError: String? = nil
    @State private var showCustomerQR = false
    @State private var showScanner = false
    
    @State private var showRewardAlert = false
    @State private var showResetConfirm = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // タイトル
                Text("ポイントカードアプリ")
                    .font(.largeTitle).bold()
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                VStack(spacing: 4) {
                    Text("10スタンプで特典！")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                }
                .padding(.top, 8)
                
                // スタンプグリッド（2行×5列 = 10個）
                StampGrid(stamps: stamps, maxStamps: maxStamps)
                    .padding(.horizontal)
                
                // 進捗表示
                ProgressView(value: Double(stamps), total: Double(maxStamps))
                    .tint(.themeAccent)
                    .padding(.horizontal)
                Text("現在 \(stamps)/\(maxStamps) スタンプ")
                    .font(.footnote)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                
                // ボタン群（お客様用：付与ボタンは非表示）
                VStack(spacing: 12) {
                    Button(action: { showRewardAlert = true }) {
                        Label("特典を受け取る", systemImage: "gift.fill")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.themeBrown)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                    .controlSize(.large)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    .disabled(stamps < maxStamps)
                }
                .padding(.top, 4)
                
                // お客さま向けQR表示
                VStack(spacing: 8) {
                    Button {
                        showCustomerQR = true
                    } label: {
                        Label("お客様用QRを表示", systemImage: "qrcode")
                            .foregroundColor(Color.themeBrown)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                    .controlSize(.large)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    Text("このQRをレジで提示 → 店側がスキャンで1スタンプ")
                        .font(.caption2)
                        .foregroundColor(Color.white.opacity(0.9))
                }
                
                // 実績
                if rewardsRedeemed > 0 {
                    Label("これまでに \(rewardsRedeemed) 回の特典を利用", systemImage: "sparkles")
                        .font(.footnote)
                        .foregroundColor(Color.white.opacity(0.9))
                        .padding(.top, 4)
                }
                
                Spacer()
            }
            .background(Color.themeBrown.ignoresSafeArea()) // brown background
            // Softer overlay to avoid dimming content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.05)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            )
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showStaffSheet = true
                    } label: {
                        Label("店員", systemImage: "person.badge.key.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { showResetConfirm = true } label: {
                        Label("リセット", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .alert("特典の利用", isPresented: $showRewardAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("受け取る") { redeemReward() }
            } message: {
                Text("スタンプが \(maxStamps) 個たまりました。特典を受け取りますか？")
            }
            .confirmationDialog("データをリセットしますか？", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("スタンプのみリセット", role: .destructive) { stamps = 0 }
                Button("すべてリセット", role: .destructive) {
                    stamps = 0
                    rewardsRedeemed = 0
                }
                Button("キャンセル", role: .cancel) {}
            }
            .sheet(isPresented: $showStaffSheet) {
                NavigationStack {
                    Form {
                        // 認証セクション
                        Section(header: Text("店員認証").foregroundColor(.white)){
                            SecureField("PIN（4桁）", text: $staffPINInput)
                                .keyboardType(.numberPad)
                                .foregroundColor(.black)
                            if staffPINInput == staffPIN {
                                Label("認証済み", systemImage: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                    .font(.footnote)
                            } else if !staffPINInput.isEmpty {
                                Label("PINが違います", systemImage: "xmark.octagon.fill")
                                    .foregroundStyle(.red)
                                    .font(.footnote)
                            }
                        }
                        
                        // 付与セクション
                        Section(header: Text("スタンプ付与").foregroundColor(.white)){
                            Text("付与レート: ￦\(yenPerPoint) = 1スタンプ")
                                .keyboardType(.numberPad)
                                .foregroundColor(.brown)
                            TextField("会計金額（円）", value: $saleAmount, format: .number)
                                .keyboardType(.numberPad)
                                .disabled(staffPINInput != staffPIN)
                                .foregroundColor(.brown)
                            Button {
                                guard staffPINInput == staffPIN else { return }
                                let amount = saleAmount ?? 0
                                let earned = max(0, amount / yenPerPoint)
                                if earned > 0 {
                                    addStamp(earned)
                                    staffError = nil
                                    saleAmount = nil
                                } else {
                                    staffError = "付与対象の金額ではありません（0スタンプ）"
                                }
                            } label: {
                                Label("金額から付与", systemImage: "cart.badge.plus")
                                    .foregroundColor(Color.themeBrown)
                                    .font(.headline)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white)
                            .buttonBorderShape(.roundedRectangle(radius: 12))
                            .controlSize(.large)
                            .opacity(staffPINInput == staffPIN ? 1.0 : 0.5)
                            .allowsHitTesting(staffPINInput == staffPIN)
                            
                            Button {
                                guard staffPINInput == staffPIN else { return }
                                addStamp(1)
                            } label: {
                                Label("スタンプを +1", systemImage: "plus.circle.fill")
                                    .foregroundColor(Color.themeBrown)
                                    .font(.headline)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white)
                            .buttonBorderShape(.roundedRectangle(radius: 12))
                            .controlSize(.large)
                            .opacity(staffPINInput == staffPIN ? 1.0 : 0.5)
                            .allowsHitTesting(staffPINInput == staffPIN)
                            
                            if let staffError {
                                Text(staffError)
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                        }
                        // スキャナ
                        Section(header: Text("QRスキャンで付与").foregroundColor(.white)) {
                            Text("お客様のQRを読み取ると +1 スタンプ")
                                .font(.caption)
                                .foregroundColor(.brown)
                            Button {
                                guard staffPINInput == staffPIN else { return }
                                showScanner = true
                            } label: {
                                Label("QRをスキャン", systemImage: "qrcode.viewfinder")
                                    .foregroundColor(Color.themeBrown)
                                    .font(.headline)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white)
                            .buttonBorderShape(.roundedRectangle(radius: 12))
                            .controlSize(.large)
                            .opacity(staffPINInput == staffPIN ? 1.0 : 0.5)
                            .allowsHitTesting(staffPINInput == staffPIN)
                        }
                    }
                  
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("店員モード")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("閉じる") { showStaffSheet = false }
                                .foregroundColor(.white)
                        }
                    }
                    .toolbarBackground(Color.themeBrown, for: .navigationBar) // ← 背景を茶色に維持
                    .toolbarColorScheme(.dark, for: .navigationBar)          // ← 白文字が見やすい設定
                    .background(Color.themeBrown.ignoresSafeArea())           // ← 画面全体の背景も茶色
                    .scrollContentBackground(.hidden)
                    .sheet(isPresented: $showScanner) {
                        NavigationStack {
                            ZStack {
                                QRScannerView { payload in
                                    // 簡易バリデーション: アプリが発行するprefixを確認
                                    if payload.hasPrefix("pointcard:") {
                                        addStamp(1)
                                    }
                                    showScanner = false
                                }
                            }
                            .navigationTitle("QRスキャン")
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button("戻る") { showScanner = false }
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCustomerQR) {
                NavigationStack {
                    VStack(spacing: 16) {
                        QRCodeView(text: "pointcard:\(customerID)")
                            .frame(width: 240, height: 240)
                            .padding()
                        Text("このQRを店員に提示してください")
                            .font(.footnote)
                            .foregroundColor(.white)
                        Button("閉じる") { showCustomerQR = false }
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.themeBrown.ignoresSafeArea())
                    .navigationTitle("お客様用QR")
                }
            }
        }
    }
    
    private func addStamp(_ n: Int) {
        guard n > 0 else { return }
        let newValue = min(stamps + n, maxStamps)
        stamps = newValue
    }
    
    private func redeemReward() {
        guard stamps >= maxStamps else { return }
        rewardsRedeemed += 1
        stamps = 0
    }
}

// MARK: - Stamp Grid Component
struct StampGrid: View {
    let stamps: Int
    let maxStamps: Int
    
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
    private var indices: [Int] { Array(0 ..< maxStamps) }  // ← 追加
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(indices, id: \.self) { (index: Int) in
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.2)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(index < stamps ? Color.white.opacity(0.75) : Color.black.opacity(0.10))
                        )
                        .frame(height: 56)
                    
                    if index < stamps {
                        Image(systemName: "seal.fill")
                            .imageScale(.large)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "seal")
                            .imageScale(.large)
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                }
                .accessibilityLabel("スタンプ \(index + 1) / \(maxStamps)")
            }
        }
    }
}
#Preview {
    ContentView()
}
// MARK: - QR Code Generator
struct QRCodeView: View {
    let text: String
    private let context = CIContext()
    
    var body: some View {
        if let image = generateQRCode(from: text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .accessibilityLabel("QRコード")
        } else {
            Image(systemName: "xmark.octagon")
        }
    }
    
    // --- QRCodeView 内の修正 ---
    // 既存: private let filter = CIFilter.qrCodeGenerator() は削除してOK（混乱の元なので消す）
    
    private func generateQRCode(from string: String) -> UIImage? {
        guard !string.isEmpty else { return nil }
        let data = Data(string.utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"   // "L", "M", "Q", "H" が選べます
        guard let outputImage = filter.outputImage else { return nil }
        
        // 10倍スケールでくっきり
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        
        // 通常はこちらでOK
        if let cgimg = context.createCGImage(scaled, from: scaled.extent) {
            return UIImage(cgImage: cgimg)
        } else {
            // まれな環境向けのフォールバック
            return UIImage(ciImage: scaled)
        }
    }
}

// MARK: - QR Scanner (AVCapture)
struct QRScannerView: UIViewControllerRepresentable {
    var onDetect: (String) -> Void
    
    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onDetect = onDetect
        return vc
    }
    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}
    
    final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onDetect: ((String) -> Void)?
        private let session = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer?
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            configureSession()
        }
        
        private func configureSession() {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }
            let output = AVCaptureMetadataOutput()
            
            session.beginConfiguration()
            if session.canAddInput(input) { session.addInput(input) }
            if session.canAddOutput(output) { session.addOutput(output) }
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
            session.commitConfiguration()
            
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
            previewLayer = layer
            
            session.startRunning()
        }
        
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  obj.type == .qr,
                  let string = obj.stringValue else { return }
            session.stopRunning()
            onDetect?(string)
            dismiss(animated: true)
        }
        
        deinit { session.stopRunning() }
    }
}
