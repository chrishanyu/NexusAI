graph TB
    subgraph "iOS Client (Swift + SwiftUI)"
        subgraph "Presentation Layer"
            AuthViews[Auth Views<br/>Login/SignUp/Profile]
            ConvListView[Conversation List View]
            ChatView[Chat View]
            GroupViews[Group Views<br/>Create/Info]
            Components[Reusable Components<br/>ProfileImage/StatusIndicator]
        end
        
        subgraph "ViewModel Layer"
            AuthVM[AuthViewModel]
            ConvListVM[ConversationListViewModel]
            ChatVM[ChatViewModel]
            PresenceMgr[PresenceManager]
            NotifMgr[NotificationManager]
        end
        
        subgraph "Service Layer"
            AuthSvc[AuthService]
            ConvSvc[ConversationService]
            MsgSvc[MessageService]
            PresenceSvc[PresenceService]
            NotifSvc[NotificationService]
            LocalStorage[LocalStorageService]
            MsgQueue[MessageQueueService]
        end
        
        subgraph "Local Persistence"
            SwiftData[(SwiftData<br/>Offline Cache)]
        end
        
        subgraph "Utilities"
            NetworkMon[NetworkMonitor]
            Constants[Constants]
            Extensions[Extensions]
        end
        
        subgraph "Models"
            UserModel[User]
            ConvModel[Conversation]
            MsgModel[Message]
            StatusModel[MessageStatus]
        end
    end
    
    subgraph "Firebase Backend"
        subgraph "Firebase Services"
            FireAuth[Firebase Auth<br/>Email/Password]
            Firestore[(Firestore<br/>NoSQL Database)]
            FCM[Firebase Cloud Messaging<br/>Push Notifications]
            CloudFunctions[Cloud Functions<br/>Serverless]
        end
        
        subgraph "Firestore Collections"
            UsersCol[users collection]
            ConvsCol[conversations collection]
            MsgsCol[messages subcollection]
            TypingCol[typingIndicators collection]
        end
        
        subgraph "Cloud Functions"
            NotifFunc[sendMessageNotification<br/>Trigger: onCreate message]
        end
    end
    
    subgraph "External Services"
        APNS[Apple Push Notification Service<br/>APNs]
    end
    
    %% Presentation to ViewModel
    AuthViews --> AuthVM
    ConvListView --> ConvListVM
    ChatView --> ChatVM
    GroupViews --> ChatVM
    
    %% ViewModel to Service
    AuthVM --> AuthSvc
    ConvListVM --> ConvSvc
    ChatVM --> MsgSvc
    ChatVM --> ConvSvc
    PresenceMgr --> PresenceSvc
    NotifMgr --> NotifSvc
    
    %% Service to Firebase
    AuthSvc --> FireAuth
    AuthSvc --> UsersCol
    ConvSvc --> ConvsCol
    MsgSvc --> MsgsCol
    MsgSvc --> ConvsCol
    PresenceSvc --> UsersCol
    PresenceSvc --> TypingCol
    NotifSvc --> FCM
    
    %% Local Storage
    MsgSvc --> LocalStorage
    ConvSvc --> LocalStorage
    LocalStorage --> SwiftData
    MsgSvc --> MsgQueue
    MsgQueue --> SwiftData
    
    %% Network Monitoring
    NetworkMon -.->|monitors| MsgQueue
    NetworkMon -.->|monitors| ChatVM
    
    %% Firebase to Collections
    Firestore --> UsersCol
    Firestore --> ConvsCol
    Firestore --> MsgsCol
    Firestore --> TypingCol
    
    %% Real-time Sync
    MsgsCol -.->|real-time listener| MsgSvc
    ConvsCol -.->|real-time listener| ConvSvc
    UsersCol -.->|real-time listener| PresenceSvc
    TypingCol -.->|real-time listener| MsgSvc
    
    %% Cloud Functions
    MsgsCol -->|onCreate trigger| NotifFunc
    NotifFunc --> FCM
    FCM --> APNS
    APNS -.->|push notification| NotifSvc
    
    %% Models used by Services
    AuthSvc --> UserModel
    ConvSvc --> ConvModel
    MsgSvc --> MsgModel
    MsgSvc --> StatusModel
    
    %% Utilities
    ChatVM --> Extensions
    ConvListVM --> Extensions
    MsgSvc --> Constants
    
    %% Styling
    classDef presentation fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    classDef viewmodel fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    classDef service fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef firebase fill:#ffccbc,stroke:#bf360c,stroke-width:2px
    classDef storage fill:#c8e6c9,stroke:#1b5e20,stroke-width:2px
    classDef external fill:#ffebee,stroke:#b71c1c,stroke-width:2px
    
    class AuthViews,ConvListView,ChatView,GroupViews,Components presentation
    class AuthVM,ConvListVM,ChatVM,PresenceMgr,NotifMgr viewmodel
    class AuthSvc,ConvSvc,MsgSvc,PresenceSvc,NotifSvc,LocalStorage,MsgQueue service
    class FireAuth,Firestore,FCM,CloudFunctions,UsersCol,ConvsCol,MsgsCol,TypingCol,NotifFunc firebase
    class SwiftData storage
    class APNS external
    