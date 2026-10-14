// Production Admin Panel JS App
document.addEventListener('DOMContentLoaded', () => {
    initNavigation();
    initLogout();
    initAdminAuthModal();
    checkAdminAuth();

    // Event delegation for search inputs
    const studentSearch = document.getElementById('studentSearch');
    if (studentSearch) studentSearch.addEventListener('input', renderStudentsTable);

    const studentFilter = document.getElementById('studentClassFilter');
    if (studentFilter) studentFilter.addEventListener('change', renderStudentsTable);

    const studentStatusFilter = document.getElementById('studentStatusFilter');
    if (studentStatusFilter) studentStatusFilter.addEventListener('change', renderStudentsTable);

    const facultySearch = document.getElementById('facultySearch');
    if (facultySearch) facultySearch.addEventListener('input', renderFacultyTable);

    const facultyDeptFilter = document.getElementById('facultyDeptFilter');
    if (facultyDeptFilter) facultyDeptFilter.addEventListener('change', renderFacultyTable);

    const facultyStatusFilter = document.getElementById('facultyStatusFilter');
    if (facultyStatusFilter) facultyStatusFilter.addEventListener('change', renderFacultyTable);

    // Attendance filters
    const attSearch = document.getElementById('attendanceSearch');
    if (attSearch) attSearch.addEventListener('input', renderAttendanceTable);
    const attClassFilter = document.getElementById('attendanceClassFilter');
    if (attClassFilter) attClassFilter.addEventListener('change', loadAttendanceTab);
    const attSubFilter = document.getElementById('attendanceSubjectFilter');
    if (attSubFilter) attSubFilter.addEventListener('change', loadAttendanceTab);
    const attStatusFilter = document.getElementById('attendanceStatusFilter');
    if (attStatusFilter) attStatusFilter.addEventListener('change', loadAttendanceTab);
    const attDateFilter = document.getElementById('attendanceDateFilter');
    if (attDateFilter) attDateFilter.addEventListener('change', loadAttendanceTab);

    // Session filters
    const sessDateFilter = document.getElementById('sessionDateFilter');
    if (sessDateFilter) sessDateFilter.addEventListener('change', loadSessionsTab);
    const sessClassFilter = document.getElementById('sessionClassFilter');
    if (sessClassFilter) sessClassFilter.addEventListener('change', loadSessionsTab);
    const sessStatusFilter = document.getElementById('sessionStatusFilter');
    if (sessStatusFilter) sessStatusFilter.addEventListener('change', loadSessionsTab);

    // Biometrics filters
    const bioSearch = document.getElementById('bioSearch');
    if (bioSearch) bioSearch.addEventListener('input', renderBiometricsTable);
    const bioStatusFilter = document.getElementById('bioStatusFilter');
    if (bioStatusFilter) bioStatusFilter.addEventListener('change', loadBiometricsTab);
    const bioClassFilter = document.getElementById('bioClassFilter');
    if (bioClassFilter) bioClassFilter.addEventListener('change', loadBiometricsTab);

    // User accounts filters
    const userSearch = document.getElementById('userSearch');
    if (userSearch) userSearch.addEventListener('input', renderUsersTable);
    const userRoleFilter = document.getElementById('userRoleFilter');
    if (userRoleFilter) userRoleFilter.addEventListener('change', loadUsersTab);
    const userStatusFilter = document.getElementById('userStatusFilter');
    if (userStatusFilter) userStatusFilter.addEventListener('change', loadUsersTab);

    const timetableClassSelect = document.getElementById('timetableClassSelect');
    if (timetableClassSelect) timetableClassSelect.addEventListener('change', renderTimetableGrid);

    const policyForm = document.getElementById('policyForm');
    if (policyForm) policyForm.addEventListener('submit', handleSavePolicy);

    const systemForm = document.getElementById('systemSettingsForm');
    if (systemForm) systemForm.addEventListener('submit', handleSaveSystemSettings);

    const notifSettingsForm = document.getElementById('notificationSettingsForm');
    if (notifSettingsForm) notifSettingsForm.addEventListener('submit', handleSaveNotificationSettings);

    const customNotifForm = document.getElementById('customNotificationForm');
    if (customNotifForm) customNotifForm.addEventListener('submit', handleSendCustomNotification);

    // Restore active support session if present and unexpired
    const savedSupport = sessionStorage.getItem('activeSupportSession');
    if (savedSupport) {
        try {
            const sess = JSON.parse(savedSupport);
            const exp = new Date(sess.expires_at).getTime();
            if (exp > Date.now()) {
                startSupportClientSession(sess);
            } else {
                sessionStorage.removeItem('activeSupportSession');
            }
        } catch (e) {}
    }
});

// Admin In-Place Auth Management
function showAdminLoginModal(msg = '') {
    const modal = document.getElementById('adminLoginModal');
    if (modal) modal.classList.remove('hidden');
    const alertBox = document.getElementById('adminLoginAlert');
    if (alertBox) {
        if (msg) {
            alertBox.textContent = msg;
            alertBox.classList.remove('hidden');
        } else {
            alertBox.classList.add('hidden');
        }
    }
}

function hideAdminLoginModal() {
    const modal = document.getElementById('adminLoginModal');
    if (modal) modal.classList.add('hidden');
}

function prefillAdminCreds() {
    const u = document.getElementById('adminUsername');
    const p = document.getElementById('adminPassword');
    if (u) u.value = 'admin';
    if (p) p.value = 'admin123';
}

function initAdminAuthModal() {
    const form = document.getElementById('adminLoginForm');
    if (!form) return;
    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const username = document.getElementById('adminUsername').value.trim();
        const password = document.getElementById('adminPassword').value;
        const btn = document.getElementById('adminLoginSubmitBtn');
        const alertBox = document.getElementById('adminLoginAlert');

        btn.disabled = true;
        btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin mr-2"></i> Signing In...';
        alertBox.classList.add('hidden');

        try {
            const res = await fetch('/api/v1/auth/login', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                },
                body: JSON.stringify({
                    username_or_email: username,
                    password: password
                })
            });

            const data = await res.json();
            if (!res.ok) {
                throw new Error(data.detail || 'Login failed');
            }

            localStorage.setItem('access_token', data.access_token);
            document.cookie = `am_token=${data.access_token}; path=/; max-age=86400; SameSite=Lax`;

            // Verify user role
            const meRes = await fetch('/api/v1/auth/me', {
                headers: {
                    'Authorization': `Bearer ${data.access_token}`,
                    'Accept': 'application/json'
                }
            });
            const me = await meRes.json();
            if (!meRes.ok || me.role !== 'ADMIN') {
                localStorage.removeItem('access_token');
                throw new Error('Access denied: Account is not an Administrator.');
            }

            hideAdminLoginModal();
            showToast("Welcome to Administrator Console", "success");
            navigateOnAuth();
        } catch (err) {
            alertBox.textContent = err.message || "Invalid administrative credentials";
            alertBox.classList.remove('hidden');
        } finally {
            btn.disabled = false;
            btn.innerHTML = '<i class="fa-solid fa-right-to-bracket mr-2"></i> Sign In as Administrator';
        }
    });
}

function navigateOnAuth() {
    const rawHash = (window.location.hash || '').replace('#', '').trim();
    if (rawHash && document.getElementById(`tab-${rawHash}`)) {
        switchTab(rawHash);
    } else {
        switchTab('dashboard');
    }
}

async function checkAdminAuth() {
    const token = localStorage.getItem('access_token');
    if (!token) {
        showAdminLoginModal();
        return false;
    }
    try {
        const user = await apiFetch('/api/v1/auth/me');
        if (user.role !== 'ADMIN') {
            showAdminLoginModal("Access restricted to Administrator role.");
            return false;
        }
        hideAdminLoginModal();
        navigateOnAuth();
        return true;
    } catch (err) {
        showAdminLoginModal("Please log in with Administrator credentials.");
        return false;
    }
}

// Cache for loaded datasets
let cachedStudents = [];
let cachedFaculty = [];
let cachedClasses = [];
let cachedSubjects = [];
let cachedPeriods = [];
let cachedAssignments = [];
let cachedTimetable = [];
let cachedAttendance = [];
let cachedSessions = [];
let cachedBiometrics = [];
let cachedUsers = [];

// Helper API Fetcher reusing existing session auth
async function apiFetch(url, options = {}) {
    const defaultHeaders = {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
    };

    // Include bearer token if stored
    const token = localStorage.getItem('access_token');
    if (token) {
        defaultHeaders['Authorization'] = `Bearer ${token}`;
    }

    const config = {
        ...options,
        headers: {
            ...defaultHeaders,
            ...options.headers
        },
        credentials: 'include'
    };

    try {
        const response = await fetch(url, config);
        if (response.status === 401 || response.status === 403) {
            const data = await response.json().catch(() => ({}));
            showAdminLoginModal(data.detail || "Administrative session expired. Please sign in.");
            throw new Error(data.detail || "Unauthorized");
        }
        if (!response.ok) {
            const errData = await response.json().catch(() => ({ detail: response.statusText }));
            const errMsg = typeof errData.detail === 'object' ? JSON.stringify(errData.detail) : (errData.detail || 'API Error');
            throw new Error(errMsg);
        }
        return await response.json();
    } catch (err) {
        console.error("API Fetch Error:", err);
        throw err;
    }
}

// Navigation & Tab Controller
function initNavigation() {
    const menuItems = document.querySelectorAll('.sidebar-menu .menu-item');
    menuItems.forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            const tabName = item.getAttribute('data-tab');
            if (tabName) {
                switchTab(tabName);
            }
        });
    });

    // Support browser back/forward and direct hash navigation
    window.addEventListener('hashchange', () => {
        const hash = (window.location.hash || '').replace('#', '').trim();
        if (hash && document.getElementById(`tab-${hash}`)) {
            switchTab(hash);
        }
    });
}

function switchTab(tabName) {
    if (!tabName) return;
    document.querySelectorAll('.sidebar-menu .menu-item').forEach(el => el.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));

    const menuItem = document.querySelector(`.menu-item[data-tab="${tabName}"]`);
    const tabContent = document.getElementById(`tab-${tabName}`);

    if (menuItem) menuItem.classList.add('active');
    if (tabContent) tabContent.classList.add('active');

    if (window.location.hash !== `#${tabName}`) {
        history.replaceState(null, '', `#${tabName}`);
    }

    // Title update
    const titleMap = {
        'dashboard': 'System Overview & Real-time Metrics',
        'students': 'Student Management & Account Security',
        'faculty': 'Faculty Management & Identity Control',
        'attendance': 'Attendance Records & Live Corrections',
        'sessions': 'Class Sessions & Timetable Linkage',
        'biometrics': 'Biometric Face Profiles & Recognition Control',
        'academic': 'Classes, Departments & Subjects',
        'timetable': 'Configurable Periods & Timetable Matrix',
        'assignments': 'Faculty Subject Assignments',
        'users': 'Central User Accounts & Access Control',
        'settings': 'Attendance Policy & System Engine Configuration',
        'bulk-import': 'College Data Bulk Seed & Import Center',
        'password-control': 'Password Change Policy & Admin Support Mode',
        'notifications': 'Push Notifications & Class Reminders Center',
        'audit': 'Security & Action Audit Trail'
    };
    document.getElementById('pageTitle').innerText = titleMap[tabName] || 'Admin Panel';

    // Trigger tab loader
    refreshTabContent(tabName);
}

function refreshCurrentTab() {
    const activeTab = document.querySelector('.tab-content.active');
    if (activeTab) {
        const tabName = activeTab.id.replace('tab-', '');
        refreshTabContent(tabName);
    }
}

function refreshTabContent(tabName) {
    switch (tabName) {
        case 'dashboard': loadDashboard(); break;
        case 'students': loadStudentsTab(); break;
        case 'faculty': loadFacultyTab(); break;
        case 'attendance': loadAttendanceTab(); break;
        case 'sessions': loadSessionsTab(); break;
        case 'biometrics': loadBiometricsTab(); break;
        case 'academic': loadAcademicTab(); break;
        case 'timetable': loadTimetableTab(); break;
        case 'assignments': loadAssignmentsTab(); break;
        case 'users': loadUsersTab(); break;
        case 'settings': loadSettingsTab(); break;
        case 'password-control': loadPasswordControlTab(); break;
        case 'notifications': loadNotificationsTab(); break;
        case 'audit': loadAuditLogs(); break;
    }
}

// Logout
function initLogout() {
    const btn = document.getElementById('logoutBtn');
    if (!btn) return;
    btn.addEventListener('click', async () => {
        try {
            await apiFetch('/api/v1/auth/logout', { method: 'POST' });
        } catch (e) { }
        localStorage.removeItem('access_token');
        document.cookie = "am_token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 UTC;";
        showToast("Logged out successfully", "success");
        showAdminLoginModal("You have been logged out.");
    });
}

// Toast Notifications
function showToast(message, type = 'success') {
    const container = document.getElementById('toastContainer');
    if (!container) return;

    const trimmedMsg = String(message || '').trim();
    if (!trimmedMsg) return;

    // Deduplicate: avoid spawning identical toast if one is already visible
    const existingToasts = container.querySelectorAll('.toast');
    for (const t of existingToasts) {
        const span = t.querySelector('span');
        if (span && span.innerText.trim() === trimmedMsg) {
            return;
        }
    }

    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    const icon = type === 'success' ? 'fa-circle-check text-success' : 'fa-circle-xmark text-danger';
    toast.innerHTML = `<i class="fa-solid ${icon}"></i> <span>${escapeHtml(trimmedMsg)}</span>`;
    container.appendChild(toast);
    setTimeout(() => { toast.remove(); }, 3500);
}

// ----------------------------------------------------
// TAB 1: DASHBOARD
// ----------------------------------------------------
async function loadDashboard() {
    try {
        const stats = await apiFetch('/api/v1/admin/dashboard-stats');
        if (document.getElementById('statStudents')) document.getElementById('statStudents').innerText = stats.total_students ?? 0;
        if (document.getElementById('statFaculty')) document.getElementById('statFaculty').innerText = stats.total_faculty ?? 0;
        if (document.getElementById('statClasses')) document.getElementById('statClasses').innerText = stats.total_classes ?? 0;
        if (document.getElementById('statSubjects')) document.getElementById('statSubjects').innerText = stats.total_subjects ?? 0;
        if (document.getElementById('statTimetable')) document.getElementById('statTimetable').innerText = stats.total_timetable_entries ?? 0;
        if (document.getElementById('statTodaySessions')) document.getElementById('statTodaySessions').innerText = stats.today_sessions ?? 0;
        if (document.getElementById('statTodayAttendance')) document.getElementById('statTodayAttendance').innerText = stats.today_attendance ?? 0;
        if (document.getElementById('statBiometricEnrolled')) document.getElementById('statBiometricEnrolled').innerText = stats.biometric_enrolled ?? 0;
        if (document.getElementById('statActiveSessions')) document.getElementById('statActiveSessions').innerText = stats.active_sessions ?? 0;

        const att = stats.attendance_stats || {};
        document.getElementById('statPresent').innerText = att.present_count || 0;
        document.getElementById('statAbsent').innerText = att.absent_count || 0;
        document.getElementById('statOD').innerText = att.od_count || 0;
        document.getElementById('statOverallPct').innerText = `${att.overall_percentage || 0}%`;
        document.getElementById('badgeMinReq').innerText = `Min Required: ${att.minimum_required_percentage || 75}%`;

        // Render Recent Audit
        const auditList = document.getElementById('recentAuditList');
        if (stats.recent_audit && stats.recent_audit.length > 0) {
            auditList.innerHTML = stats.recent_audit.map(l => `
                <li class="audit-item">
                    <div class="audit-action"><strong>${escapeHtml(l.action)}</strong></div>
                    <div class="audit-details text-muted">${escapeHtml(l.details)}</div>
                    <div class="audit-time small">${formatDate(l.timestamp)}</div>
                </li>
            `).join('');
        } else {
            auditList.innerHTML = '<li class="text-muted">No audit events recorded yet.</li>';
        }
    } catch (e) {
        showToast("Failed to load dashboard metrics", "danger");
    }
}

// ----------------------------------------------------
// CAPACITY & STATS HELPERS
// ----------------------------------------------------
async function updateCapacityBadges() {
    try {
        const stats = await apiFetch('/api/v1/admin/capacity-stats');
        
        // Students Badge
        const stCountEl = document.getElementById('studentCapCurrent');
        const stMaxEl = document.getElementById('studentCapMax');
        const stRemEl = document.getElementById('studentCapRemaining');
        const stBadge = document.getElementById('studentCapacityBadge');
        const btnAddStudent = document.getElementById('btnAddStudent');

        if (stCountEl && stats.students) {
            stCountEl.innerText = stats.students.current;
            if (stMaxEl) stMaxEl.innerText = stats.students.max;
            stRemEl.innerText = `Remaining: ${stats.students.remaining}`;
            stBadge.classList.remove('cap-warning', 'cap-full');
            if (stats.students.remaining === 0) {
                stBadge.classList.add('cap-full');
                stRemEl.className = 'badge badge-danger';
                if (btnAddStudent) {
                    btnAddStudent.disabled = true;
                    btnAddStudent.title = `Student capacity reached (${stats.students.max}/${stats.students.max})`;
                }
            } else if (stats.students.remaining <= 5) {
                stBadge.classList.add('cap-warning');
                stRemEl.className = 'badge badge-warning';
                if (btnAddStudent) btnAddStudent.disabled = false;
            } else {
                stRemEl.className = 'badge badge-info';
                if (btnAddStudent) btnAddStudent.disabled = false;
            }
        }

        // Faculty Badge
        const facCountEl = document.getElementById('facultyCapCurrent');
        const facMaxEl = document.getElementById('facultyCapMax');
        const facRemEl = document.getElementById('facultyCapRemaining');
        const facBadge = document.getElementById('facultyCapacityBadge');
        const btnAddFaculty = document.getElementById('btnAddFaculty');

        if (facCountEl && stats.faculty) {
            facCountEl.innerText = stats.faculty.current;
            if (facMaxEl) facMaxEl.innerText = stats.faculty.max;
            facRemEl.innerText = `Remaining: ${stats.faculty.remaining}`;
            facBadge.classList.remove('cap-warning', 'cap-full');
            if (stats.faculty.remaining === 0) {
                facBadge.classList.add('cap-full');
                facRemEl.className = 'badge badge-danger';
                if (btnAddFaculty) {
                    btnAddFaculty.disabled = true;
                    btnAddFaculty.title = `Faculty capacity reached (${stats.faculty.max}/${stats.faculty.max})`;
                }
            } else if (stats.faculty.remaining <= 3) {
                facBadge.classList.add('cap-warning');
                facRemEl.className = 'badge badge-warning';
                if (btnAddFaculty) btnAddFaculty.disabled = false;
            } else {
                facRemEl.className = 'badge badge-info';
                if (btnAddFaculty) btnAddFaculty.disabled = false;
            }
        }
    } catch (e) {
        console.warn("Could not refresh capacity badges:", e);
    }
}


// ----------------------------------------------------
// TAB 2: STUDENTS
// ----------------------------------------------------
async function loadStudentsTab() {
    try {
        const [students, classes] = await Promise.all([
            apiFetch('/api/v1/admin/students'),
            apiFetch('/api/v1/admin/classes')
        ]);
        cachedStudents = students;
        cachedClasses = classes;

        // Populate class filter dropdown
        const filterSelect = document.getElementById('studentClassFilter');
        if (filterSelect) {
            filterSelect.innerHTML = '<option value="">All Class Sections</option>' +
                classes.map(c => `<option value="${c.id}">${escapeHtml(c.name)}</option>`).join('');
        }

        renderStudentsTable();
        updateCapacityBadges();
    } catch (e) {
        showToast("Failed to load students list", "danger");
    }
}

let studentCurrentPage = 1;
const studentPageSize = 50;

function changeStudentPage(newPage) {
    studentCurrentPage = newPage;
    renderStudentsTable(false);
}

function renderStudentsTable(resetPage = true) {
    if (resetPage) studentCurrentPage = 1;
    const searchVal = (document.getElementById('studentSearch')?.value || '').toLowerCase().trim();
    const classVal = document.getElementById('studentClassFilter')?.value;
    const statusVal = document.getElementById('studentStatusFilter')?.value;

    const filtered = cachedStudents.filter(s => {
        const matchText = (s.full_name || '').toLowerCase().includes(searchVal) ||
            (s.roll_number || '').toLowerCase().includes(searchVal) ||
            (s.email || '').toLowerCase().includes(searchVal);
        const matchClass = !classVal || s.class_id == classVal;
        const matchStatus = statusVal === "" || (statusVal === "true" ? s.is_active : !s.is_active);
        return matchText && matchClass && matchStatus;
    });

    const tbody = document.querySelector('#studentsTable tbody');
    const pageInfo = document.getElementById('studentsPageInfo');
    const pageControls = document.getElementById('studentsPageControls');
    if (!tbody) return;

    const totalRecords = filtered.length;
    const totalPages = Math.ceil(totalRecords / studentPageSize) || 1;
    if (studentCurrentPage > totalPages) studentCurrentPage = totalPages;
    if (studentCurrentPage < 1) studentCurrentPage = 1;

    if (totalRecords === 0) {
        tbody.innerHTML = '<tr><td colspan="7" class="text-center text-muted">No matching student records found.</td></tr>';
        if (pageInfo) pageInfo.innerText = 'Showing 0 of 0 students';
        if (pageControls) pageControls.innerHTML = '';
        return;
    }

    const startIdx = (studentCurrentPage - 1) * studentPageSize;
    const pageItems = filtered.slice(startIdx, startIdx + studentPageSize);

    if (pageInfo) {
        pageInfo.innerText = `Showing ${startIdx + 1}–${Math.min(startIdx + studentPageSize, totalRecords)} of ${totalRecords.toLocaleString()} students (Page ${studentCurrentPage} of ${totalPages})`;
    }
    if (pageControls) {
        pageControls.innerHTML = `
            <button class="btn btn-sm btn-outline-secondary" ${studentCurrentPage <= 1 ? 'disabled' : ''} onclick="changeStudentPage(1)" title="First Page">«</button>
            <button class="btn btn-sm btn-outline-secondary" ${studentCurrentPage <= 1 ? 'disabled' : ''} onclick="changeStudentPage(${studentCurrentPage - 1})" title="Previous Page">‹ Prev</button>
            <span class="btn btn-sm btn-outline-secondary active" style="pointer-events:none; font-weight:600;">${studentCurrentPage} / ${totalPages}</span>
            <button class="btn btn-sm btn-outline-secondary" ${studentCurrentPage >= totalPages ? 'disabled' : ''} onclick="changeStudentPage(${studentCurrentPage + 1})" title="Next Page">Next ›</button>
            <button class="btn btn-sm btn-outline-secondary" ${studentCurrentPage >= totalPages ? 'disabled' : ''} onclick="changeStudentPage(${totalPages})" title="Last Page">»</button>
        `;
    }

    tbody.innerHTML = pageItems.map(s => {
        const classObj = cachedClasses.find(c => c.id === s.class_id);
        const className = classObj ? classObj.name : (s.class_name || '<span class="text-muted">Unassigned</span>');
        const deptSem = [s.department || '', s.semester ? `Sem ${s.semester}` : ''].filter(Boolean).join(' • ') || '<span class="text-muted">—</span>';
        const activeBadge = s.is_active
            ? '<span class="badge badge-success"><i class="fa-solid fa-circle-check"></i> Active</span>'
            : '<span class="badge badge-danger"><i class="fa-solid fa-ban"></i> Disabled</span>';

        return `
            <tr>
                <td><strong>${escapeHtml(s.roll_number)}</strong></td>
                <td>${escapeHtml(s.full_name)}</td>
                <td>${escapeHtml(s.email || '—')}</td>
                <td>${className}</td>
                <td><small class="text-muted">${deptSem}</small></td>
                <td>${activeBadge}</td>
                <td>
                    <div class="btn-group gap-1">
                        <button class="btn btn-sm btn-outline-secondary" onclick="openEditStudentModal(${s.id})" title="Edit Student">
                            <i class="fa-solid fa-pen"></i>
                        </button>
                        <button class="btn btn-sm ${s.is_active ? 'btn-outline-danger' : 'btn-outline-success'}" onclick="${s.is_active ? `confirmDisableStudent(${s.id}, '${escapeHtml(s.full_name)}')` : `enableStudent(${s.id})`}" title="${s.is_active ? 'Disable Account' : 'Enable Account'}">
                            <i class="fa-solid ${s.is_active ? 'fa-user-slash' : 'fa-user-check'}"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-warning" onclick="openResetPasswordModal('student', ${s.id}, '${escapeHtml(s.full_name)}', '${escapeHtml(s.roll_number)}')" title="Reset Password">
                            <i class="fa-solid fa-key"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-info" onclick="forceStudentPasswordChange(${s.id}, '${escapeHtml(s.full_name)}')" title="Force Password Update">
                            <i class="fa-solid fa-shield-halved"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-primary" onclick="promptStartSupportMode('student', ${s.id}, '${escapeHtml(s.full_name)}')" title="Admin Support Mode">
                            <i class="fa-solid fa-user-secret"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-danger" onclick="confirmDeleteStudent(${s.id}, '${escapeHtml(s.full_name)}', '${escapeHtml(s.roll_number)}')" title="Delete Student">
                            <i class="fa-solid fa-trash"></i>
                        </button>
                    </div>
                </td>
            </tr>
        `;
    }).join('');
}

function openCreateStudentModal() {
    const classOpts = cachedClasses.map(c => `<option value="${c.id}">${escapeHtml(c.name)}</option>`).join('');
    const body = `
        <form id="createStudentForm">
            <div class="grid-2-col gap-3">
                <div class="form-group">
                    <label>Roll / Register Number *</label>
                    <input type="text" id="newRoll" class="form-control" required placeholder="e.g. 23CY001">
                </div>
                <div class="form-group">
                    <label>Full Name *</label>
                    <input type="text" id="newName" class="form-control" required placeholder="Full legal name">
                </div>
            </div>

            <div class="grid-2-col gap-3 mt-2">
                <div class="form-group">
                    <label>College Email</label>
                    <input type="email" id="newEmail" class="form-control" placeholder="student@college.edu">
                </div>
                <div class="form-group">
                    <label>Class Section</label>
                    <select id="newClassId" class="form-control">
                        <option value="">Select Class Section</option>
                        ${classOpts}
                    </select>
                </div>
            </div>

            <div class="grid-2-col gap-3 mt-2">
                <div class="form-group">
                    <label>Department</label>
                    <input type="text" id="newDept" class="form-control" placeholder="e.g. Cyber Security">
                </div>
                <div class="form-group">
                    <label>Semester</label>
                    <input type="text" id="newSem" class="form-control" placeholder="e.g. 3">
                </div>
            </div>

            <div class="form-group mt-3">
                <label>Password Options</label>
                <div class="flex flex-col gap-2 mt-1">
                    <label class="d-flex align-center gap-2 font-normal">
                        <input type="checkbox" id="newGenerateTemp" checked onchange="toggleCustomPasswordInput(this, 'newCustomPwBox')">
                        <span>Generate Cryptographically Secure Temporary Password <em>(Recommended)</em></span>
                    </label>
                    <div id="newCustomPwBox" style="display: none;" class="mt-1">
                        <input type="password" id="newPassword" class="form-control" placeholder="Enter custom temporary password">
                    </div>
                    <label class="d-flex align-center gap-2 font-normal text-muted small">
                        <input type="checkbox" id="newForcePw" checked>
                        <span>Require password change on next mobile login</span>
                    </label>
                </div>
            </div>

            <div class="modal-actions mt-4">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="submit" class="btn btn-success"><i class="fa-solid fa-plus"></i> Create Student</button>
            </div>
        </form>
    `;
    openAdminModal("Create New Student Account", body);

    document.getElementById('createStudentForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const generateTemp = document.getElementById('newGenerateTemp').checked;
        const customPw = document.getElementById('newPassword').value;
        const rollNum = document.getElementById('newRoll').value.trim();
        const fullName = document.getElementById('newName').value.trim();

        const payload = {
            roll_number: rollNum,
            full_name: fullName,
            email: document.getElementById('newEmail').value.trim() || null,
            class_id: document.getElementById('newClassId').value ? parseInt(document.getElementById('newClassId').value) : null,
            department: document.getElementById('newDept').value.trim() || null,
            semester: document.getElementById('newSem').value.trim() || null,
            generate_temporary: generateTemp,
            password: generateTemp ? null : customPw,
            force_password_change: document.getElementById('newForcePw').checked,
            is_active: true
        };

        try {
            const res = await apiFetch('/api/v1/admin/students', {
                method: 'POST',
                body: JSON.stringify(payload)
            });
            showToast("Student created successfully", "success");
            closeAdminModal();
            loadStudentsTab();

            // If temporary password was returned, reveal it in a secure one-time dialog
            if (res.temporary_password) {
                showTemporaryPasswordModal('Student', fullName, res.temporary_password);
            }
        } catch (err) {
            showToast(err.message || "Failed to create student", "danger");
        }
    });
}

function openEditStudentModal(studentId) {
    const student = cachedStudents.find(s => s.id === studentId);
    if (!student) return;

    const classOpts = cachedClasses.map(c => `<option value="${c.id}" ${c.id === student.class_id ? 'selected' : ''}>${escapeHtml(c.name)}</option>`).join('');
    const body = `
        <form id="editStudentForm">
            <div class="grid-2-col gap-3">
                <div class="form-group">
                    <label>Roll / Register Number *</label>
                    <input type="text" id="editRoll" class="form-control" required value="${escapeHtml(student.roll_number)}">
                </div>
                <div class="form-group">
                    <label>Username / Login ID</label>
                    <input type="text" id="editUsername" class="form-control" value="${escapeHtml(student.username || student.login_identifier || '')}">
                </div>
            </div>

            <div class="grid-2-col gap-3 mt-2">
                <div class="form-group">
                    <label>Full Name *</label>
                    <input type="text" id="editName" class="form-control" required value="${escapeHtml(student.full_name)}">
                </div>
                <div class="form-group">
                    <label>College Email</label>
                    <input type="email" id="editEmail" class="form-control" value="${escapeHtml(student.email || '')}">
                </div>
            </div>

            <div class="grid-2-col gap-3 mt-2">
                <div class="form-group">
                    <label>Class Section</label>
                    <select id="editClassId" class="form-control">
                        <option value="">Select Class Section</option>
                        ${classOpts}
                    </select>
                </div>
                <div class="form-group">
                    <label>Phone Number</label>
                    <input type="text" id="editPhone" class="form-control" value="${escapeHtml(student.phone || '')}">
                </div>
            </div>

            <div class="grid-2-col gap-3 mt-2">
                <div class="form-group">
                    <label>Department</label>
                    <input type="text" id="editDept" class="form-control" value="${escapeHtml(student.department || '')}">
                </div>
                <div class="form-group">
                    <label>Semester</label>
                    <input type="text" id="editSem" class="form-control" value="${escapeHtml(student.semester || '')}">
                </div>
            </div>

            <div class="form-group mt-3">
                <label>Security & Account Status</label>
                <div class="flex flex-col gap-2 mt-1">
                    <label class="d-flex align-center gap-2 font-normal">
                        <input type="checkbox" id="editActive" ${student.is_active ? 'checked' : ''}>
                        <span>Account Active (Uncheck to disable student login)</span>
                    </label>
                    <label class="d-flex align-center gap-2 font-normal text-muted small">
                        <input type="checkbox" id="editForcePw" ${student.force_password_change ? 'checked' : ''}>
                        <span>Require password change on next mobile login</span>
                    </label>
                    <div class="mt-2">
                        <label class="small text-muted">Set New Password (optional, leave blank to keep unchanged):</label>
                        <input type="password" id="editNewPw" class="form-control" placeholder="Enter new password">
                    </div>
                </div>
            </div>

            <div class="modal-actions mt-4">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="submit" class="btn btn-primary"><i class="fa-solid fa-save"></i> Save Changes</button>
            </div>
        </form>
    `;
    openAdminModal(`Edit Student — ${student.full_name}`, body);

    document.getElementById('editStudentForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const payload = {
            roll_number: document.getElementById('editRoll').value.trim(),
            username: document.getElementById('editUsername').value.trim() || null,
            full_name: document.getElementById('editName').value.trim(),
            email: document.getElementById('editEmail').value.trim() || null,
            phone: document.getElementById('editPhone').value.trim() || null,
            class_id: document.getElementById('editClassId').value ? parseInt(document.getElementById('editClassId').value) : null,
            department: document.getElementById('editDept').value.trim() || null,
            semester: document.getElementById('editSem').value.trim() || null,
            is_active: document.getElementById('editActive').checked,
            force_password_change: document.getElementById('editForcePw').checked
        };
        const newPw = document.getElementById('editNewPw').value;
        if (newPw) {
            payload.new_password = newPw;
        }

        try {
            await apiFetch(`/api/v1/admin/students/${studentId}`, {
                method: 'PUT',
                body: JSON.stringify(payload)
            });
            showToast("Student updated successfully", "success");
            closeAdminModal();
            loadStudentsTab();
        } catch (err) {
            showToast(err.message || "Failed to update student", "danger");
        }
    });
}

function confirmDeleteStudent(studentId, fullName, rollNumber) {
    const body = `
        <div class="alert alert-danger">
            <i class="fa-solid fa-triangle-exclamation"></i>
            <strong>Permanent Deletion Warning:</strong>
            Deleting <strong>${escapeHtml(fullName)} (${escapeHtml(rollNumber)})</strong> will permanently remove their profile, biometric face embeddings, and linked user account.
        </div>
        <p class="text-muted small mt-2"><strong>Referential Safety Rule:</strong> If this student has existing attendance records, deletion will be blocked to preserve historical academic integrity. You should disable the account instead.</p>
        <div class="modal-actions mt-4">
            <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
            <button type="button" class="btn btn-danger" onclick="executeDeleteStudent(${studentId})">
                <i class="fa-solid fa-trash"></i> Delete Student
            </button>
        </div>
    `;
    openAdminModal(`Delete Student — ${fullName}`, body);
}

async function executeDeleteStudent(studentId) {
    try {
        const res = await apiFetch(`/api/v1/admin/students/${studentId}`, { method: 'DELETE' });
        showToast(res.message || "Student deleted successfully", "success");
        closeAdminModal();
        loadStudentsTab();
    } catch (e) {
        showToast(e.message || "Failed to delete student", "danger");
    }
}

function confirmDisableStudent(studentId, fullName) {
    const body = `
        <p>Are you sure you want to <strong>disable</strong> account access for <strong>${escapeHtml(fullName)}</strong>?</p>
        <p class="text-muted small mt-2">The student will be blocked from logging into the mobile app and active sessions will be revoked. Their attendance history will remain intact.</p>
        <div class="modal-actions mt-4">
            <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
            <button type="button" class="btn btn-danger" onclick="executeDisableStudent(${studentId})"><i class="fa-solid fa-ban"></i> Disable Student</button>
        </div>
    `;
    openAdminModal("Confirm Disable Student", body);
}

async function executeDisableStudent(studentId) {
    try {
        const res = await apiFetch(`/api/v1/admin/students/${studentId}/disable`, { method: 'POST' });
        showToast(res.message, "success");
        closeAdminModal();
        loadStudentsTab();
    } catch (e) {
        showToast(e.message || "Failed to disable student", "danger");
    }
}

async function enableStudent(studentId) {
    try {
        const res = await apiFetch(`/api/v1/admin/students/${studentId}/enable`, { method: 'POST' });
        showToast(res.message, "success");
        loadStudentsTab();
    } catch (e) {
        showToast(e.message || "Failed to enable student", "danger");
    }
}

async function forceStudentPasswordChange(studentId, fullName) {
    try {
        const res = await apiFetch(`/api/v1/admin/students/${studentId}/force-password-change`, { method: 'POST' });
        showToast(`Mandatory password change flagged for ${fullName}`, "info");
        loadStudentsTab();
    } catch (e) {
        showToast(e.message || "Failed to flag password change", "danger");
    }
}


// ----------------------------------------------------
// TAB 3: FACULTY
// ----------------------------------------------------
async function loadFacultyTab() {
    try {
        const faculty = await apiFetch('/api/v1/admin/faculty');
        cachedFaculty = faculty;

        // Populate department filter
        const deptFilter = document.getElementById('facultyDeptFilter');
        if (deptFilter) {
            const depts = Array.from(new Set(faculty.map(f => f.department).filter(Boolean))).sort();
            deptFilter.innerHTML = '<option value="">All Departments</option>' +
                depts.map(d => `<option value="${escapeHtml(d)}">${escapeHtml(d)}</option>`).join('');
        }

        renderFacultyTable();
        updateCapacityBadges();
    } catch (e) {
        showToast("Failed to load faculty members", "danger");
    }
}

let facultyCurrentPage = 1;
const facultyPageSize = 25;

function changeFacultyPage(newPage) {
    facultyCurrentPage = newPage;
    renderFacultyTable(false);
}

function renderFacultyTable(resetPage = true) {
    if (resetPage) facultyCurrentPage = 1;
    const searchVal = (document.getElementById('facultySearch')?.value || '').toLowerCase().trim();
    const deptVal = document.getElementById('facultyDeptFilter')?.value;
    const statusVal = document.getElementById('facultyStatusFilter')?.value;

    const filtered = cachedFaculty.filter(f => {
        const matchText = (f.full_name || '').toLowerCase().includes(searchVal) ||
            (f.employee_id || '').toLowerCase().includes(searchVal) ||
            (f.username || '').toLowerCase().includes(searchVal) ||
            (f.email || '').toLowerCase().includes(searchVal);
        const matchDept = !deptVal || f.department === deptVal;
        const matchStatus = statusVal === "" || (statusVal === "true" ? f.is_active : !f.is_active);
        return matchText && matchDept && matchStatus;
    });

    const tbody = document.querySelector('#facultyTable tbody');
    const pageInfo = document.getElementById('facultyPageInfo');
    const pageControls = document.getElementById('facultyPageControls');
    if (!tbody) return;

    const totalRecords = filtered.length;
    const totalPages = Math.ceil(totalRecords / facultyPageSize) || 1;
    if (facultyCurrentPage > totalPages) facultyCurrentPage = totalPages;
    if (facultyCurrentPage < 1) facultyCurrentPage = 1;

    if (totalRecords === 0) {
        tbody.innerHTML = '<tr><td colspan="7" class="text-center text-muted">No faculty members found.</td></tr>';
        if (pageInfo) pageInfo.innerText = 'Showing 0 of 0 faculty';
        if (pageControls) pageControls.innerHTML = '';
        return;
    }

    const startIdx = (facultyCurrentPage - 1) * facultyPageSize;
    const pageItems = filtered.slice(startIdx, startIdx + facultyPageSize);

    if (pageInfo) {
        pageInfo.innerText = `Showing ${startIdx + 1}–${Math.min(startIdx + facultyPageSize, totalRecords)} of ${totalRecords.toLocaleString()} faculty (Page ${facultyCurrentPage} of ${totalPages})`;
    }
    if (pageControls) {
        pageControls.innerHTML = `
            <button class="btn btn-sm btn-outline-secondary" ${facultyCurrentPage <= 1 ? 'disabled' : ''} onclick="changeFacultyPage(1)" title="First Page">«</button>
            <button class="btn btn-sm btn-outline-secondary" ${facultyCurrentPage <= 1 ? 'disabled' : ''} onclick="changeFacultyPage(${facultyCurrentPage - 1})" title="Previous Page">‹ Prev</button>
            <span class="btn btn-sm btn-outline-secondary active" style="pointer-events:none; font-weight:600;">${facultyCurrentPage} / ${totalPages}</span>
            <button class="btn btn-sm btn-outline-secondary" ${facultyCurrentPage >= totalPages ? 'disabled' : ''} onclick="changeFacultyPage(${facultyCurrentPage + 1})" title="Next Page">Next ›</button>
            <button class="btn btn-sm btn-outline-secondary" ${facultyCurrentPage >= totalPages ? 'disabled' : ''} onclick="changeFacultyPage(${totalPages})" title="Last Page">»</button>
        `;
    }

    tbody.innerHTML = pageItems.map(f => {
        const activeBadge = f.is_active
            ? '<span class="badge badge-success"><i class="fa-solid fa-circle-check"></i> Active</span>'
            : '<span class="badge badge-danger"><i class="fa-solid fa-ban"></i> Disabled</span>';

        const typeBadge = f.is_dev_account
            ? '<span class="badge-dev-account" title="Temporary Development Faculty"><i class="fa-solid fa-flask"></i> Development</span>'
            : '<span class="badge badge-success" title="Official College Faculty"><i class="fa-solid fa-building-columns"></i> Official</span>';

        return `
            <tr>
                <td><strong>${escapeHtml(f.employee_id)}</strong></td>
                <td>${escapeHtml(f.full_name)}</td>
                <td>${escapeHtml(f.department || 'General')}</td>
                <td>${escapeHtml(f.email || f.username)}</td>
                <td>${typeBadge}</td>
                <td>${activeBadge}</td>
                <td>
                    <div class="btn-group gap-1">
                        <button class="btn btn-sm btn-outline-secondary" onclick="openEditFacultyModal(${f.id})" title="Edit Faculty">
                            <i class="fa-solid fa-pen"></i>
                        </button>
                        <button class="btn btn-sm ${f.is_active ? 'btn-outline-danger' : 'btn-outline-success'}" onclick="${f.is_active ? `confirmDisableFaculty(${f.id}, '${escapeHtml(f.full_name)}')` : `enableFaculty(${f.id})`}" title="${f.is_active ? 'Disable Account' : 'Enable Account'}">
                            <i class="fa-solid ${f.is_active ? 'fa-user-slash' : 'fa-user-check'}"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-warning" onclick="openResetPasswordModal('faculty', ${f.id}, '${escapeHtml(f.full_name)}', '${escapeHtml(f.employee_id)}')" title="Reset Password">
                            <i class="fa-solid fa-key"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-info" onclick="forceFacultyPasswordChange(${f.id}, '${escapeHtml(f.full_name)}')" title="Force Password Update">
                            <i class="fa-solid fa-shield-halved"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-primary" onclick="promptStartSupportMode('faculty', ${f.id}, '${escapeHtml(f.full_name)}')" title="Admin Support Mode">
                            <i class="fa-solid fa-user-secret"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-danger" onclick="confirmDeleteFaculty(${f.id}, '${escapeHtml(f.full_name)}', '${escapeHtml(f.employee_id)}')" title="Delete Faculty">
                            <i class="fa-solid fa-trash"></i>
                        </button>
                    </div>
                </td>
            </tr>
        `;
    }).join('');
}

function openCreateFacultyModal() {
    const body = `
        <form id="createFacultyForm">
            <div class="grid-2-col gap-3">
                <div class="form-group">
                    <label>Employee ID *</label>
                    <input type="text" id="facEmpId" class="form-control" required placeholder="e.g. EMP101">
                </div>
                <div class="form-group">
                    <label>Full Name *</label>
                    <input type="text" id="facName" class="form-control" required placeholder="Dr. Jane Doe">
                </div>
            </div>

            <div class="grid-2-col gap-3 mt-2">
                <div class="form-group">
                    <label>Username / Login ID *</label>
                    <input type="text" id="facUser" class="form-control" required placeholder="jane_doe">
                </div>
                <div class="form-group">
                    <label>College Email *</label>
                    <input type="email" id="facEmail" class="form-control" required placeholder="jane@college.edu">
                </div>
            </div>

            <div class="grid-2-col gap-3 mt-2">
                <div class="form-group">
                    <label>Department</label>
                    <input type="text" id="facDept" class="form-control" placeholder="Computer Science">
                </div>
                <div class="form-group">
                    <label>Phone Number</label>
                    <input type="text" id="facPhone" class="form-control" placeholder="+91 9876543210">
                </div>
            </div>

            <div class="form-group mt-3">
                <label>Password Options</label>
                <div class="flex flex-col gap-2 mt-1">
                    <label class="d-flex align-center gap-2 font-normal">
                        <input type="checkbox" id="facGenerateTemp" checked onchange="toggleCustomPasswordInput(this, 'facCustomPwBox')">
                        <span>Generate Cryptographically Secure Temporary Password <em>(Recommended)</em></span>
                    </label>
                    <div id="facCustomPwBox" style="display: none;" class="mt-1">
                        <input type="password" id="facPassword" class="form-control" placeholder="Enter custom temporary password">
                    </div>
                    <label class="d-flex align-center gap-2 font-normal text-muted small">
                        <input type="checkbox" id="facForcePw" checked>
                        <span>Require password change on next mobile login</span>
                    </label>
                </div>
            </div>

            <div class="modal-actions mt-4">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="submit" class="btn btn-success"><i class="fa-solid fa-plus"></i> Create Faculty</button>
            </div>
        </form>
    `;
    openAdminModal("Create Faculty Member Account", body);

    document.getElementById('createFacultyForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const generateTemp = document.getElementById('facGenerateTemp').checked;
        const customPw = document.getElementById('facPassword').value;
        const fullName = document.getElementById('facName').value.trim();

        const payload = {
            employee_id: document.getElementById('facEmpId').value.trim(),
            full_name: fullName,
            department: document.getElementById('facDept').value.trim() || null,
            username: document.getElementById('facUser').value.trim(),
            email: document.getElementById('facEmail').value.trim(),
            phone: document.getElementById('facPhone').value.trim() || null,
            generate_temporary: generateTemp,
            password: generateTemp ? null : customPw,
            force_password_change: document.getElementById('facForcePw').checked,
            is_active: true
        };

        try {
            const res = await apiFetch('/api/v1/admin/faculty', {
                method: 'POST',
                body: JSON.stringify(payload)
            });
            showToast("Faculty member created successfully", "success");
            closeAdminModal();
            loadFacultyTab();

            if (res.temporary_password) {
                showTemporaryPasswordModal('Faculty', fullName, res.temporary_password);
            }
        } catch (err) {
            showToast(err.message || "Failed to create faculty", "danger");
        }
    });
}

function openEditFacultyModal(facultyId) {
    const faculty = cachedFaculty.find(f => f.id === facultyId);
    if (!faculty) return;

    const body = `
        <form id="editFacultyForm">
            <div class="grid-2-col gap-3">
                <div class="form-group">
                    <label>Employee ID *</label>
                    <input type="text" id="editFacEmpId" class="form-control" required value="${escapeHtml(faculty.employee_id)}">
                </div>
                <div class="form-group">
                    <label>Username / Login ID *</label>
                    <input type="text" id="editFacUsername" class="form-control" required value="${escapeHtml(faculty.username)}">
                </div>
            </div>

            <div class="grid-2-col gap-3 mt-2">
                <div class="form-group">
                    <label>Full Name *</label>
                    <input type="text" id="editFacName" class="form-control" required value="${escapeHtml(faculty.full_name)}">
                </div>
                <div class="form-group">
                    <label>College Email *</label>
                    <input type="email" id="editFacEmail" class="form-control" required value="${escapeHtml(faculty.email || '')}">
                </div>
            </div>

            <div class="grid-2-col gap-3 mt-2">
                <div class="form-group">
                    <label>Department</label>
                    <input type="text" id="editFacDept" class="form-control" value="${escapeHtml(faculty.department || '')}">
                </div>
                <div class="form-group">
                    <label>Phone Number</label>
                    <input type="text" id="editFacPhone" class="form-control" value="${escapeHtml(faculty.phone || '')}">
                </div>
            </div>

            <div class="grid-2-col gap-3 mt-2">
                <div class="form-group">
                    <label>System Role</label>
                    <select id="editFacRole" class="form-control">
                        <option value="FACULTY">FACULTY</option>
                        <option value="ADMIN">ADMIN</option>
                    </select>
                </div>
            </div>

            <div class="form-group mt-3">
                <label>Security & Account Status</label>
                <div class="flex flex-col gap-2 mt-1">
                    <label class="d-flex align-center gap-2 font-normal">
                        <input type="checkbox" id="editFacActive" ${faculty.is_active ? 'checked' : ''}>
                        <span>Account Active (Uncheck to disable faculty login)</span>
                    </label>
                    <label class="d-flex align-center gap-2 font-normal text-muted small">
                        <input type="checkbox" id="editFacForcePw" ${faculty.force_password_change ? 'checked' : ''}>
                        <span>Require password change on next mobile login</span>
                    </label>
                    <div class="mt-2">
                        <label class="small text-muted">Set New Password (optional, leave blank to keep unchanged):</label>
                        <input type="password" id="editFacNewPw" class="form-control" placeholder="Enter new password">
                    </div>
                </div>
            </div>

            <div class="modal-actions mt-4">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="submit" class="btn btn-primary"><i class="fa-solid fa-save"></i> Save Changes</button>
            </div>
        </form>
    `;
    openAdminModal(`Edit Faculty — ${faculty.full_name}`, body);

    document.getElementById('editFacultyForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const payload = {
            employee_id: document.getElementById('editFacEmpId').value.trim(),
            username: document.getElementById('editFacUsername').value.trim(),
            full_name: document.getElementById('editFacName').value.trim(),
            email: document.getElementById('editFacEmail').value.trim(),
            department: document.getElementById('editFacDept').value.trim() || null,
            phone: document.getElementById('editFacPhone').value.trim() || null,
            role: document.getElementById('editFacRole').value,
            is_active: document.getElementById('editFacActive').checked,
            force_password_change: document.getElementById('editFacForcePw').checked
        };
        const newPw = document.getElementById('editFacNewPw').value;
        if (newPw) {
            payload.new_password = newPw;
        }

        try {
            await apiFetch(`/api/v1/admin/faculty/${facultyId}`, {
                method: 'PUT',
                body: JSON.stringify(payload)
            });
            showToast("Faculty updated successfully", "success");
            closeAdminModal();
            loadFacultyTab();
        } catch (err) {
            showToast(err.message || "Failed to update faculty", "danger");
        }
    });
}

function confirmDeleteFaculty(facultyId, fullName, employeeId) {
    const body = `
        <div class="alert alert-danger">
            <i class="fa-solid fa-triangle-exclamation"></i>
            <strong>Permanent Deletion Warning:</strong>
            Deleting faculty member <strong>${escapeHtml(fullName)} (${escapeHtml(employeeId)})</strong> will permanently remove their profile and login account.
        </div>
        <p class="text-muted small mt-2"><strong>Referential Safety Rule:</strong> If this faculty member is referenced by class sessions or course assignments, deletion will be rejected. Deactivate the account or reassign courses first.</p>
        <div class="modal-actions mt-4">
            <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
            <button type="button" class="btn btn-danger" onclick="executeDeleteFaculty(${facultyId})">
                <i class="fa-solid fa-trash"></i> Delete Faculty
            </button>
        </div>
    `;
    openAdminModal(`Delete Faculty — ${fullName}`, body);
}

async function executeDeleteFaculty(facultyId) {
    try {
        const res = await apiFetch(`/api/v1/admin/faculty/${facultyId}`, { method: 'DELETE' });
        showToast(res.message || "Faculty deleted successfully", "success");
        closeAdminModal();
        loadFacultyTab();
    } catch (e) {
        showToast(e.message || "Failed to delete faculty", "danger");
    }
}

function confirmDisableFaculty(facultyId, fullName) {
    const body = `
        <p>Are you sure you want to <strong>disable</strong> account access for <strong>${escapeHtml(fullName)}</strong>?</p>
        <p class="text-muted small mt-2">The faculty member will be blocked from logging into the mobile app and active sessions will be revoked. Assigned timetable slots will remain in the database.</p>
        <div class="modal-actions mt-4">
            <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
            <button type="button" class="btn btn-danger" onclick="executeDisableFaculty(${facultyId})"><i class="fa-solid fa-ban"></i> Disable Faculty</button>
        </div>
    `;
    openAdminModal("Confirm Disable Faculty", body);
}

async function executeDisableFaculty(facultyId) {
    try {
        const res = await apiFetch(`/api/v1/admin/faculty/${facultyId}/disable`, { method: 'POST' });
        showToast(res.message, "success");
        closeAdminModal();
        loadFacultyTab();
    } catch (e) {
        showToast(e.message || "Failed to disable faculty", "danger");
    }
}

async function enableFaculty(facultyId) {
    try {
        const res = await apiFetch(`/api/v1/admin/faculty/${facultyId}/enable`, { method: 'POST' });
        showToast(res.message, "success");
        loadFacultyTab();
    } catch (e) {
        showToast(e.message || "Failed to enable faculty", "danger");
    }
}

async function forceFacultyPasswordChange(facultyId, fullName) {
    try {
        const res = await apiFetch(`/api/v1/admin/faculty/${facultyId}/force-password-change`, { method: 'POST' });
        showToast(`Mandatory password change flagged for ${fullName}`, "info");
        loadFacultyTab();
    } catch (e) {
        showToast(e.message || "Failed to flag password change", "danger");
    }
}


// ----------------------------------------------------
// PASSWORD LIFECYCLE & ONE-TIME REVEAL MODAL
// ----------------------------------------------------
function toggleCustomPasswordInput(checkbox, targetBoxId) {
    const targetBox = document.getElementById(targetBoxId);
    if (targetBox) {
        targetBox.style.display = checkbox.checked ? 'none' : 'block';
        const input = targetBox.querySelector('input');
        if (input) {
            input.required = !checkbox.checked;
            if (checkbox.checked) input.value = '';
        }
    }
}

function openResetPasswordModal(role, id, name, identifier = '') {
    const identSub = identifier ? ` — Identifier: <code>${escapeHtml(identifier)}</code>` : '';
    const body = `
        <form id="resetPasswordForm">
            <p class="text-muted">Reset credentials for <strong>${escapeHtml(name)}</strong> (${role})${identSub}:</p>
            
            <div class="form-group mt-3">
                <label>Reset Options</label>
                <div class="flex flex-col gap-2 mt-1">
                    <label class="d-flex align-center gap-2 font-normal">
                        <input type="checkbox" id="resetGenerateTemp" checked onchange="toggleCustomPasswordInput(this, 'resetCustomPwBox')">
                        <span>Generate Cryptographically Secure Temporary Password <em>(Recommended)</em></span>
                    </label>
                    <div id="resetCustomPwBox" style="display: none;" class="mt-1">
                        <input type="password" id="resetNewPw" class="form-control" placeholder="Enter custom new password">
                    </div>
                    <label class="d-flex align-center gap-2 font-normal text-muted small">
                        <input type="checkbox" id="resetForcePw" checked>
                        <span>Require password change on next mobile login</span>
                    </label>
                </div>
            </div>

            <div class="modal-actions mt-4">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="submit" class="btn btn-warning"><i class="fa-solid fa-key"></i> Reset Password</button>
            </div>
        </form>
    `;
    openAdminModal(`Reset Password — ${name}`, body);

    document.getElementById('resetPasswordForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const generateTemp = document.getElementById('resetGenerateTemp').checked;
        const customPw = document.getElementById('resetNewPw').value;
        const endpoint = role === 'faculty' ? `/api/v1/admin/faculty/${id}/reset-password` : `/api/v1/admin/students/${id}/reset-password`;

        const payload = {
            generate_temporary: generateTemp,
            new_password: generateTemp ? null : customPw,
            force_password_change: document.getElementById('resetForcePw').checked
        };

        try {
            const res = await apiFetch(endpoint, {
                method: 'POST',
                body: JSON.stringify(payload)
            });
            showToast("Password reset successfully", "success");
            closeAdminModal();

            if (res.temporary_password) {
                showTemporaryPasswordModal(role === 'faculty' ? 'Faculty' : 'Student', name, res.temporary_password, identifier);
            }
        } catch (err) {
            showToast(err.message || "Failed to reset password", "danger");
        }
    });
}

function showTemporaryPasswordModal(role, name, tempPassword, identifier = '') {
    const identHtml = identifier ? `
        <div style="background: rgba(30,58,138,0.06); border-radius: 8px; padding: 10px 14px; margin-bottom: 14px; display: inline-block;">
            <span style="font-size: 12px; color: #64748b; font-weight: 600; text-transform: uppercase;">Login ID / Register Number:</span>
            <div style="font-family: monospace; font-size: 16px; font-weight: bold; color: #1e293b; margin-top: 2px;">${escapeHtml(identifier)}</div>
        </div>
    ` : '';
    const body = `
        <div class="text-center">
            <p class="mb-2">A new temporary password has been generated for <strong>${escapeHtml(name)}</strong> (${role}):</p>
            ${identHtml}
            <div class="credential-reveal-box">
                <div class="credential-value-display" id="revealedTempPassword">${escapeHtml(tempPassword)}</div>
                <div class="mt-3">
                    <button class="btn btn-primary" onclick="copyTemporaryPassword('${escapeHtml(tempPassword)}')">
                        <i class="fa-solid fa-copy"></i> Copy to Clipboard
                    </button>
                </div>
            </div>

            <div class="credential-warning-banner">
                <i class="fa-solid fa-triangle-exclamation"></i>
                <div>
                    <strong>IMPORTANT NOTICE:</strong>
                    <p class="m-0 mt-1">Copy this temporary password now. It is stored as a secure one-way bcrypt hash and will <strong>NOT</strong> be displayed again.</p>
                </div>
            </div>

            <div class="modal-actions mt-4">
                <button type="button" class="btn btn-success btn-block" onclick="closeAdminModal()">Done</button>
            </div>
        </div>
    `;
    openAdminModal("Temporary Credential Generated", body);
}

function copyTemporaryPassword(password) {
    const cleanPw = typeof password === 'string' ? password.trim() : String(password || '').trim();
    navigator.clipboard.writeText(cleanPw).then(() => {
        showToast("Temporary password copied to clipboard!", "success");
    }).catch(() => {
        showToast("Please copy the password manually from the box.", "info");
    });
}


// ----------------------------------------------------
// TAB 4: ACADEMIC (Classes & Subjects)
// ----------------------------------------------------
async function loadAcademicTab() {
    try {
        const [classes, subjects, facultyList] = await Promise.all([
            apiFetch('/api/v1/admin/classes'),
            apiFetch('/api/v1/admin/subjects'),
            apiFetch('/api/v1/admin/faculty').catch(() => [])
        ]);
        cachedClasses = classes;
        cachedSubjects = subjects;
        cachedFaculty = facultyList;

        // Render Classes
        const classesBody = document.querySelector('#classesTable tbody');
        if (classes.length === 0) {
            classesBody.innerHTML = '<tr><td colspan="6" class="text-center text-muted">No class sections configured.</td></tr>';
        } else {
            classesBody.innerHTML = classes.map(c => {
                const advisorDisplay = c.class_advisor_name
                    ? `<div><strong class="text-primary"><i class="fa-solid fa-user-tie mr-1"></i>${escapeHtml(c.class_advisor_name)}</strong><br><small class="text-muted">${escapeHtml(c.class_advisor_employee_id || '')}</small></div>`
                    : `<span class="badge badge-warning"><i class="fa-solid fa-triangle-exclamation mr-1"></i>Unassigned</span>`;
                const escapedName = escapeHtml(c.name).replace(/'/g, "\\'");

                return `
                <tr>
                    <td><strong>${escapeHtml(c.name)}</strong></td>
                    <td>${escapeHtml(c.grade_level || 'Default')}</td>
                    <td>${escapeHtml(c.academic_year || '2026-2027')}</td>
                    <td><span class="badge badge-info">${c.student_count ?? 0} Students</span></td>
                    <td>${advisorDisplay}</td>
                    <td>
                        <div class="btn-group gap-1">
                            <button class="btn btn-sm btn-outline-primary" onclick="openAssignAdvisorModal(${c.id}, '${escapedName}', ${c.class_advisor_id || 'null'})" title="${c.class_advisor_id ? 'Change Advisor' : 'Assign Advisor'}">
                                <i class="fa-solid fa-user-tie"></i> ${c.class_advisor_id ? 'Change' : 'Assign'}
                            </button>
                            ${c.class_advisor_id ? `
                            <button class="btn btn-sm btn-outline-warning" onclick="removeAdvisor(${c.id}, '${escapedName}')" title="Remove Advisor">
                                <i class="fa-solid fa-user-xmark"></i>
                            </button>` : ''}
                            <button class="btn btn-sm btn-outline-secondary" onclick="openEditClassModal(${c.id})" title="Edit Class">
                                <i class="fa-solid fa-pen"></i>
                            </button>
                            <button class="btn btn-sm btn-outline-danger" onclick="deleteClass(${c.id})" title="Delete Class">
                                <i class="fa-solid fa-trash"></i>
                            </button>
                        </div>
                    </td>
                </tr>
            `}).join('');
        }

        // Render Subjects
        const subjectsBody = document.querySelector('#subjectsTable tbody');
        if (subjects.length === 0) {
            subjectsBody.innerHTML = '<tr><td colspan="4" class="text-center text-muted">No subjects configured.</td></tr>';
        } else {
            subjectsBody.innerHTML = subjects.map(s => `
                <tr>
                    <td><strong>${escapeHtml(s.code)}</strong></td>
                    <td>${escapeHtml(s.name)}</td>
                    <td>${escapeHtml(s.description || '—')}</td>
                    <td>
                        <div class="btn-group gap-1">
                            <button class="btn btn-sm btn-outline-secondary" onclick="openEditSubjectModal(${s.id})" title="Edit Subject">
                                <i class="fa-solid fa-pen"></i>
                            </button>
                            <button class="btn btn-sm btn-outline-danger" onclick="deleteSubject(${s.id})" title="Delete Subject">
                                <i class="fa-solid fa-trash"></i>
                            </button>
                        </div>
                    </td>
                </tr>
            `).join('');
        }
    } catch (e) {
        showToast("Failed to load academic configuration", "danger");
    }
}

function openCreateClassModal() {
    const body = `
        <form id="createClassForm">
            <div class="form-group">
                <label>Class Name *</label>
                <input type="text" id="clsName" class="form-control" required placeholder="e.g. II Year CSE Cyber Security - Class 1">
            </div>
            <div class="form-group">
                <label>Grade / Year Level</label>
                <input type="text" id="clsGrade" class="form-control" placeholder="e.g. II Year">
            </div>
            <div class="form-group">
                <label>Academic Year</label>
                <input type="text" id="clsYear" class="form-control" value="2026-2027">
            </div>
            <button type="submit" class="btn btn-primary btn-block mt-3">Add Class Section</button>
        </form>
    `;
    openAdminModal("Add Class Section", body);

    document.getElementById('createClassForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const payload = {
            name: document.getElementById('clsName').value.trim(),
            grade_level: document.getElementById('clsGrade').value.trim(),
            academic_year: document.getElementById('clsYear').value.trim()
        };

        try {
            await apiFetch('/api/v1/admin/classes', { method: 'POST', body: JSON.stringify(payload) });
            showToast("Class section added", "success");
            closeAdminModal();
            loadAcademicTab();
        } catch (err) {
            showToast(err.message || "Failed to create class section", "danger");
        }
    });
}

function openEditClassModal(classId) {
    const cls = cachedClasses.find(c => c.id === classId);
    if (!cls) return;

    const body = `
        <form id="editClassForm">
            <div class="form-group">
                <label>Class Name *</label>
                <input type="text" id="editClsName" class="form-control" required value="${escapeHtml(cls.name)}">
            </div>
            <div class="form-group">
                <label>Grade / Year Level</label>
                <input type="text" id="editClsGrade" class="form-control" value="${escapeHtml(cls.grade_level || '')}">
            </div>
            <div class="form-group">
                <label>Academic Year</label>
                <input type="text" id="editClsYear" class="form-control" value="${escapeHtml(cls.academic_year || '2026-2027')}">
            </div>
            <div class="modal-actions mt-3">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="submit" class="btn btn-primary"><i class="fa-solid fa-save"></i> Save Changes</button>
            </div>
        </form>
    `;
    openAdminModal(`Edit Class Section — ${cls.name}`, body);

    document.getElementById('editClassForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const payload = {
            name: document.getElementById('editClsName').value.trim(),
            grade_level: document.getElementById('editClsGrade').value.trim(),
            academic_year: document.getElementById('editClsYear').value.trim()
        };

        try {
            await apiFetch(`/api/v1/admin/classes/${classId}`, { method: 'PUT', body: JSON.stringify(payload) });
            showToast("Class section updated", "success");
            closeAdminModal();
            loadAcademicTab();
        } catch (err) {
            showToast(err.message || "Failed to update class", "danger");
        }
    });
}

async function openAssignAdvisorModal(classId, className, currentAdvisorId) {
    let faculty = cachedFaculty;
    if (!faculty || faculty.length === 0) {
        try {
            faculty = await apiFetch('/api/v1/admin/faculty');
            cachedFaculty = faculty;
        } catch (e) {
            faculty = [];
        }
    }

    const optionsHtml = faculty.map(f => {
        const isSelected = currentAdvisorId && Number(currentAdvisorId) === Number(f.id) ? 'selected' : '';
        return `<option value="${f.id}" ${isSelected}>${escapeHtml(f.full_name)} (${escapeHtml(f.employee_id)}) - ${escapeHtml(f.department || 'Academic')}</option>`;
    }).join('');

    const body = `
        <form id="assignAdvisorForm">
            <div class="form-group mb-3">
                <label>Target Class</label>
                <input type="text" class="form-control" value="${escapeHtml(className)}" readonly disabled style="background: #0b1120; color: #94a3b8;">
            </div>
            <div class="form-group mb-3">
                <label>Select Faculty Member *</label>
                <select id="advisorFacultySelect" class="form-control" required style="background: #0b1120; color: #f8fafc;">
                    <option value="">-- Choose Faculty --</option>
                    ${optionsHtml}
                </select>
            </div>
            <div class="alert alert-info mt-2" style="font-size: 0.82rem; padding: 10px; border-radius: 6px; background: rgba(59, 130, 246, 0.1); border: 1px solid rgba(59, 130, 246, 0.2); color: #93c5fd;">
                <i class="fa-solid fa-circle-info mr-1"></i> The assigned Class Advisor has full period-by-period attendance management authority (P1–P7) for every student in this class, subject to optimistic concurrency conflict protection.
            </div>
            <div class="flex justify-end gap-2 mt-4">
                <button type="button" class="btn btn-outline-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="submit" class="btn btn-primary"><i class="fa-solid fa-check mr-1"></i> Save Advisor Assignment</button>
            </div>
        </form>
    `;
    openAdminModal(`Assign Class Advisor: ${className}`, body);

    document.getElementById('assignAdvisorForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const selId = document.getElementById('advisorFacultySelect').value;
        if (!selId) {
            showToast("Please choose a faculty member", "danger");
            return;
        }
        try {
            await apiFetch(`/api/v1/admin/classes/${classId}/advisor`, {
                method: 'POST',
                body: JSON.stringify({ faculty_id: Number(selId) })
            });
            showToast(`Class Advisor assigned to "${className}" successfully`, "success");
            closeAdminModal();
            loadAcademicTab();
        } catch (err) {
            showToast(err.message || "Failed to assign Class Advisor", "danger");
        }
    });
}

async function removeAdvisor(classId, className) {
    if (!confirm(`Are you sure you want to remove the Class Advisor from "${className}"?`)) {
        return;
    }
    try {
        await apiFetch(`/api/v1/admin/classes/${classId}/advisor`, {
            method: 'DELETE'
        });
        showToast(`Class Advisor removed from "${className}"`, "success");
        loadAcademicTab();
    } catch (err) {
        showToast(err.message || "Failed to remove Class Advisor", "danger");
    }
}

async function deleteClass(id) {
    if (!confirm("Are you sure you want to delete this class section?")) return;
    try {
        await apiFetch(`/api/v1/admin/classes/${id}`, { method: 'DELETE' });
        showToast("Class section deleted", "success");
        loadAcademicTab();
    } catch (err) {
        showToast(err.message || "Failed to delete class", "danger");
    }
}

function openCreateSubjectModal() {
    const body = `
        <form id="createSubjectForm">
            <div class="form-group">
                <label>Subject Code *</label>
                <input type="text" id="subCode" class="form-control" required placeholder="e.g. IKS" maxlength="20">
            </div>
            <div class="form-group">
                <label>Subject Name *</label>
                <input type="text" id="subName" class="form-control" required placeholder="e.g. Indian Knowledge System" maxlength="100">
            </div>
            <div class="form-group">
                <label>Description</label>
                <input type="text" id="subDesc" class="form-control" placeholder="Theory / Lab syllabus" maxlength="255">
            </div>
            <button type="submit" class="btn btn-primary btn-block mt-3"><i class="fa-solid fa-plus"></i> Create Subject</button>
        </form>
    `;
    openAdminModal("Create Subject", body);

    document.getElementById('createSubjectForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const code = document.getElementById('subCode').value.trim();
        const name = document.getElementById('subName').value.trim();
        const desc = document.getElementById('subDesc').value.trim();

        if (!code) {
            showToast("Subject code cannot be empty", "warning");
            return;
        }
        if (!name) {
            showToast("Subject name cannot be empty", "warning");
            return;
        }

        const payload = {
            code: code,
            name: name,
            description: desc || null
        };

        try {
            await apiFetch('/api/v1/admin/subjects', { method: 'POST', body: JSON.stringify(payload) });
            showToast(`Subject '${code}' created successfully`, "success");
            closeAdminModal();
            loadAcademicTab();
        } catch (err) {
            showToast(err.message || "Failed to create subject", "danger");
        }
    });
}

function openEditSubjectModal(subjectId) {
    const sub = cachedSubjects.find(s => s.id === subjectId);
    if (!sub) return;

    const body = `
        <form id="editSubjectForm">
            <div class="form-group">
                <label>Subject Code *</label>
                <input type="text" id="editSubCode" class="form-control" required value="${escapeHtml(sub.code)}" maxlength="20">
            </div>
            <div class="form-group">
                <label>Subject Name *</label>
                <input type="text" id="editSubName" class="form-control" required value="${escapeHtml(sub.name)}" maxlength="100">
            </div>
            <div class="form-group">
                <label>Description</label>
                <input type="text" id="editSubDesc" class="form-control" value="${escapeHtml(sub.description || '')}" maxlength="255">
            </div>
            <div class="modal-actions mt-3">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="submit" class="btn btn-primary"><i class="fa-solid fa-save"></i> Save Changes</button>
            </div>
        </form>
    `;
    openAdminModal(`Edit Subject — ${sub.code}`, body);

    document.getElementById('editSubjectForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const code = document.getElementById('editSubCode').value.trim();
        const name = document.getElementById('editSubName').value.trim();
        const desc = document.getElementById('editSubDesc').value.trim();

        if (!code || !name) {
            showToast("Code and Name are required", "warning");
            return;
        }

        const payload = {
            code,
            name,
            description: desc || null
        };

        try {
            await apiFetch(`/api/v1/admin/subjects/${subjectId}`, { method: 'PUT', body: JSON.stringify(payload) });
            showToast(`Subject '${code}' updated successfully`, "success");
            closeAdminModal();
            loadAcademicTab();
        } catch (err) {
            showToast(err.message || "Failed to update subject", "danger");
        }
    });
}

async function deleteSubject(id) {
    if (!confirm("Are you sure you want to delete this subject?")) return;
    try {
        await apiFetch(`/api/v1/admin/subjects/${id}`, { method: 'DELETE' });
        showToast("Subject deleted", "success");
        loadAcademicTab();
    } catch (err) {
        showToast(err.message || "Failed to delete subject", "danger");
    }
}

// ----------------------------------------------------
// ----------------------------------------------------
// TAB 5: TIMETABLE & PERIODS
// ----------------------------------------------------
const WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

async function loadTimetableTab() {
    try {
        const [periods, classes, subjects, faculty] = await Promise.all([
            apiFetch('/api/v1/admin/periods'),
            apiFetch('/api/v1/admin/classes'),
            apiFetch('/api/v1/admin/subjects'),
            apiFetch('/api/v1/admin/faculty')
        ]);
        cachedPeriods = periods.sort((a, b) => a.period_number - b.period_number);
        cachedClasses = classes;
        cachedSubjects = subjects;
        cachedFaculty = faculty;

        // Periods Table
        const pBody = document.querySelector('#periodsTable tbody');
        if (periods.length === 0) {
            pBody.innerHTML = '<tr><td colspan="4" class="text-center text-muted">No periods configured.</td></tr>';
        } else {
            pBody.innerHTML = cachedPeriods.map(p => `
                <tr>
                    <td><strong>P${p.period_number}</strong></td>
                    <td>${escapeHtml(p.name)}</td>
                    <td>${escapeHtml(p.start_time)} – ${escapeHtml(p.end_time)}</td>
                    <td>
                        <button class="btn btn-sm btn-outline-danger" onclick="deletePeriod(${p.id})"><i class="fa-solid fa-trash"></i></button>
                    </td>
                </tr>
            `).join('');
        }

        // Timetable Class Dropdown
        const select = document.getElementById('timetableClassSelect');
        const prevSelected = select ? select.value : '';
        if (classes.length === 0) {
            select.innerHTML = '<option value="">No classes found</option>';
        } else {
            select.innerHTML = classes.map(c => `<option value="${c.id}">${escapeHtml(c.name)}</option>`).join('');
            if (prevSelected && classes.some(c => c.id == prevSelected)) {
                select.value = prevSelected;
            } else {
                select.value = classes[0].id;
            }
        }

        await renderTimetableGrid();
    } catch (e) {
        showToast("Failed to load timetable configuration", "danger");
    }
}

function togglePeriodsCollapse() {
    const p = document.getElementById('periodsConfigPanel');
    if (p) p.classList.toggle('hidden');
}

async function renderTimetableGrid() {
    const select = document.getElementById('timetableClassSelect');
    const classId = select ? select.value : null;
    const container = document.getElementById('timetableGridContainer');
    if (!classId || !container) {
        if (container) container.innerHTML = '<p class="text-center text-muted p-4">Select a class section to view and edit its timetable.</p>';
        return;
    }

    try {
        const [entries, periods] = await Promise.all([
            apiFetch(`/api/v1/admin/timetable?class_id=${classId}`),
            cachedPeriods && cachedPeriods.length ? Promise.resolve(cachedPeriods) : apiFetch('/api/v1/admin/periods')
        ]);
        cachedTimetable = entries;
        cachedPeriods = periods.sort((a, b) => a.period_number - b.period_number);

        if (cachedPeriods.length === 0) {
            container.innerHTML = '<p class="text-center text-muted p-4">No periods configured. Please add period timings first.</p>';
            return;
        }

        // Build Map: day -> period_id -> entry
        const entryMap = {};
        entries.forEach(e => {
            const dayKey = e.day_of_week;
            if (!entryMap[dayKey]) entryMap[dayKey] = {};
            entryMap[dayKey][e.period_id] = e;
        });

        let html = '<table class="timetable-grid-table"><thead><tr><th>Day</th>';
        cachedPeriods.forEach(p => {
            html += `
                <th>
                    <span class="th-pnum">P${p.period_number} (${escapeHtml(p.name)})</span>
                    <span class="th-timing">${escapeHtml(p.start_time)}–${escapeHtml(p.end_time)}</span>
                </th>
            `;
        });
        html += '</tr></thead><tbody>';

        WEEKDAYS.forEach(day => {
            html += `<tr><td class="day-col">${day.toUpperCase().substring(0, 3)}<br><small class="text-muted">${day}</small></td>`;
            cachedPeriods.forEach(p => {
                const entry = entryMap[day] ? entryMap[day][p.id] : null;
                if (entry) {
                    const isPending = !entry.faculty_name || entry.faculty_name === 'Faculty assignment pending' || entry.faculty_name.toLowerCase().includes('pending');
                    const facDisplay = isPending
                        ? '<span class="slot-faculty pending"><i class="fa-solid fa-clock-rotate-left"></i> Faculty pending</span>'
                        : `<span class="slot-faculty"><i class="fa-solid fa-user-check"></i> ${escapeHtml(entry.faculty_name)}</span>`;

                    const roomDisplay = entry.room ? `<div class="slot-room"><i class="fa-solid fa-location-dot"></i> ${escapeHtml(entry.room)}</div>` : '';

                    html += `
                        <td class="slot-cell" id="slot_${entry.id}">
                            <div class="slot-card-inner">
                                <div class="slot-header">
                                    <span class="slot-code">${escapeHtml(entry.subject_code || '-')}</span>
                                    <small class="slot-time text-muted">${escapeHtml(p.start_time)}</small>
                                </div>
                                <div class="slot-name" title="${escapeHtml(entry.subject_name || '')}">${escapeHtml(entry.subject_name || '')}</div>
                                ${facDisplay}
                                ${roomDisplay}
                                <div class="slot-actions">
                                    <button class="btn-slot-action" title="Edit Slot" onclick="openEditTimetableModal(${entry.id})"><i class="fa-solid fa-pen"></i></button>
                                    <button class="btn-slot-action" title="Move Slot" onclick="openMoveTimetableModal(${entry.id})"><i class="fa-solid fa-arrows-up-down-left-right"></i></button>
                                    <button class="btn-slot-action" title="Duplicate Slot" onclick="openDuplicateTimetableModal(${entry.id})"><i class="fa-solid fa-copy"></i></button>
                                    <button class="btn-slot-action act-delete" title="Clear Slot" onclick="confirmDeleteTimetableEntry(${entry.id})"><i class="fa-solid fa-trash"></i></button>
                                </div>
                            </div>
                        </td>
                    `;
                } else {
                    html += `
                        <td class="slot-cell">
                            <div class="slot-empty" onclick="openCreateTimetableModalFor('${day}', ${p.id})">
                                <button class="btn-add-empty"><i class="fa-solid fa-plus"></i> Add</button>
                            </div>
                        </td>
                    `;
                }
            });
            html += '</tr>';
        });

        html += '</tbody></table>';
        container.innerHTML = html;

    } catch (e) {
        container.innerHTML = `<p class="text-center text-danger p-4">Error loading timetable: ${escapeHtml(e.message || '')}</p>`;
    }
}

function openCreateTimetableModalFor(day, periodId) {
    openCreateTimetableModal(day, periodId);
}

async function openCreateTimetableModal(prefilledDay = '', prefilledPeriodId = null) {
    try {
        const [classes, subjects, faculty, periods] = await Promise.all([
            cachedClasses && cachedClasses.length ? Promise.resolve(cachedClasses) : apiFetch('/api/v1/admin/classes'),
            cachedSubjects && cachedSubjects.length ? Promise.resolve(cachedSubjects) : apiFetch('/api/v1/admin/subjects'),
            cachedFaculty && cachedFaculty.length ? Promise.resolve(cachedFaculty) : apiFetch('/api/v1/admin/faculty'),
            cachedPeriods && cachedPeriods.length ? Promise.resolve(cachedPeriods) : apiFetch('/api/v1/admin/periods')
        ]);

        const selectedClassId = document.getElementById('timetableClassSelect') ? document.getElementById('timetableClassSelect').value : (classes[0] ? classes[0].id : '');

        const classOptions = classes.map(c => `<option value="${c.id}" ${c.id == selectedClassId ? 'selected' : ''}>${escapeHtml(c.name)}</option>`).join('');
        const dayOptions = WEEKDAYS.map(d => `<option value="${d}" ${d === prefilledDay ? 'selected' : ''}>${d}</option>`).join('');
        const periodOptions = periods.sort((a, b) => a.period_number - b.period_number).map(p => `
            <option value="${p.id}" ${p.id == prefilledPeriodId ? 'selected' : ''}>P${p.period_number}: ${escapeHtml(p.name)} (${escapeHtml(p.start_time)}–${escapeHtml(p.end_time)})</option>
        `).join('');
        const subjectOptions = subjects.map(s => `<option value="${s.id}">${escapeHtml(s.code)} – ${escapeHtml(s.name)}</option>`).join('');
        const activeFaculty = faculty.filter(f => f.is_active !== false);
        const facultyOptions = `<option value="">-- Faculty assignment pending (Unassigned) --</option>` +
            activeFaculty.map(f => `<option value="${f.id}">${escapeHtml(f.full_name)} (${escapeHtml(f.employee_id)})</option>`).join('');

        const body = `
            <form id="createTimetableForm">
                <div class="form-group">
                    <label>Class Section *</label>
                    <select id="ttClassId" class="form-control" required>
                        ${classOptions}
                    </select>
                </div>
                <div class="form-row-2">
                    <div class="form-group">
                        <label>Day of Week *</label>
                        <select id="ttDay" class="form-control" required>
                            ${dayOptions}
                        </select>
                    </div>
                    <div class="form-group">
                        <label>Period Slot *</label>
                        <select id="ttPeriodId" class="form-control" required>
                            ${periodOptions}
                        </select>
                    </div>
                </div>
                <div class="form-group">
                    <label>Subject *</label>
                    <select id="ttSubjectId" class="form-control" required>
                        ${subjectOptions}
                    </select>
                </div>
                <div class="form-group">
                    <label>Assigned Faculty</label>
                    <select id="ttFacultyId" class="form-control">
                        ${facultyOptions}
                    </select>
                    <small class="text-muted">Select active faculty or leave as pending assignment.</small>
                </div>
                <div class="form-group">
                    <label>Room / Hall (Optional)</label>
                    <input type="text" id="ttRoom" class="form-control" placeholder="e.g. Lab 3, Hall 204">
                </div>
                <button type="submit" class="btn btn-success btn-block mt-3"><i class="fa-solid fa-plus"></i> Add Timetable Slot</button>
            </form>
        `;

        openAdminModal("Add Timetable Slot", body);

        document.getElementById('createTimetableForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const facVal = document.getElementById('ttFacultyId').value;
            const payload = {
                class_id: parseInt(document.getElementById('ttClassId').value),
                day_of_week: document.getElementById('ttDay').value,
                period_id: parseInt(document.getElementById('ttPeriodId').value),
                subject_id: parseInt(document.getElementById('ttSubjectId').value),
                faculty_id: facVal ? parseInt(facVal) : null,
                room: document.getElementById('ttRoom').value.trim() || null
            };

            try {
                await apiFetch('/api/v1/admin/timetable', { method: 'POST', body: JSON.stringify(payload) });
                showToast("Timetable slot created successfully", "success");
                closeAdminModal();
                renderTimetableGrid();
            } catch (err) {
                showToast(err.message || "Failed to create timetable slot", "danger");
            }
        });

    } catch (e) {
        showToast("Failed to prepare timetable creation modal", "danger");
    }
}

async function openEditTimetableModal(entryId) {
    const entry = cachedTimetable.find(t => t.id === entryId);
    if (!entry) {
        showToast("Entry not found in cache. Refreshing...", "warning");
        renderTimetableGrid();
        return;
    }

    try {
        const [classes, subjects, faculty, periods] = await Promise.all([
            cachedClasses && cachedClasses.length ? Promise.resolve(cachedClasses) : apiFetch('/api/v1/admin/classes'),
            cachedSubjects && cachedSubjects.length ? Promise.resolve(cachedSubjects) : apiFetch('/api/v1/admin/subjects'),
            cachedFaculty && cachedFaculty.length ? Promise.resolve(cachedFaculty) : apiFetch('/api/v1/admin/faculty'),
            cachedPeriods && cachedPeriods.length ? Promise.resolve(cachedPeriods) : apiFetch('/api/v1/admin/periods')
        ]);

        const classOptions = classes.map(c => `<option value="${c.id}" ${c.id == entry.class_id ? 'selected' : ''}>${escapeHtml(c.name)}</option>`).join('');
        const dayOptions = WEEKDAYS.map(d => `<option value="${d}" ${d.toLowerCase() === entry.day_of_week.toLowerCase() ? 'selected' : ''}>${d}</option>`).join('');
        const periodOptions = periods.sort((a, b) => a.period_number - b.period_number).map(p => `
            <option value="${p.id}" ${p.id == entry.period_id ? 'selected' : ''}>P${p.period_number}: ${escapeHtml(p.name)} (${escapeHtml(p.start_time)}–${escapeHtml(p.end_time)})</option>
        `).join('');
        const subjectOptions = subjects.map(s => `<option value="${s.id}" ${s.id == entry.subject_id ? 'selected' : ''}>${escapeHtml(s.code)} – ${escapeHtml(s.name)}</option>`).join('');
        const activeFaculty = faculty.filter(f => f.is_active !== false);
        const facultyOptions = `<option value="">-- Faculty assignment pending (Unassigned) --</option>` +
            activeFaculty.map(f => `<option value="${f.id}" ${f.id == entry.faculty_id ? 'selected' : ''}>${escapeHtml(f.full_name)} (${escapeHtml(f.employee_id)})</option>`).join('');

        const body = `
            <form id="editTimetableForm">
                <div class="form-group">
                    <label>Class Section</label>
                    <select id="editTtClassId" class="form-control" required>
                        ${classOptions}
                    </select>
                </div>
                <div class="form-row-2">
                    <div class="form-group">
                        <label>Day of Week *</label>
                        <select id="editTtDay" class="form-control" required>
                            ${dayOptions}
                        </select>
                    </div>
                    <div class="form-group">
                        <label>Period Slot *</label>
                        <select id="editTtPeriodId" class="form-control" required>
                            ${periodOptions}
                        </select>
                    </div>
                </div>
                <div class="form-group">
                    <label>Subject *</label>
                    <select id="editTtSubjectId" class="form-control" required>
                        ${subjectOptions}
                    </select>
                </div>
                <div class="form-group">
                    <label>Assigned Faculty</label>
                    <select id="editTtFacultyId" class="form-control">
                        ${facultyOptions}
                    </select>
                </div>
                <div class="form-group">
                    <label>Room / Hall (Optional)</label>
                    <input type="text" id="editTtRoom" class="form-control" value="${escapeHtml(entry.room || '')}" placeholder="e.g. Lab 3">
                </div>
                <button type="submit" class="btn btn-primary btn-block mt-3"><i class="fa-solid fa-floppy-disk"></i> Save Timetable Changes</button>
            </form>
        `;

        openAdminModal(`Edit Timetable Slot #${entry.id}`, body);

        document.getElementById('editTimetableForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const facVal = document.getElementById('editTtFacultyId').value;
            const payload = {
                class_id: parseInt(document.getElementById('editTtClassId').value),
                day_of_week: document.getElementById('editTtDay').value,
                period_id: parseInt(document.getElementById('editTtPeriodId').value),
                subject_id: parseInt(document.getElementById('editTtSubjectId').value),
                faculty_id: facVal ? parseInt(facVal) : 0,
                room: document.getElementById('editTtRoom').value.trim() || null
            };

            try {
                await apiFetch(`/api/v1/admin/timetable/${entryId}`, { method: 'PUT', body: JSON.stringify(payload) });
                showToast("Timetable slot updated successfully", "success");
                closeAdminModal();
                renderTimetableGrid();
            } catch (err) {
                showToast(err.message || "Failed to update timetable slot", "danger");
            }
        });

    } catch (e) {
        showToast("Failed to prepare edit modal", "danger");
    }
}

async function openMoveTimetableModal(entryId) {
    const entry = cachedTimetable.find(t => t.id === entryId);
    if (!entry) return;

    const periods = cachedPeriods || [];
    const dayOptions = WEEKDAYS.map(d => `<option value="${d}" ${d.toLowerCase() === entry.day_of_week.toLowerCase() ? 'selected' : ''}>${d}</option>`).join('');
    const periodOptions = periods.sort((a, b) => a.period_number - b.period_number).map(p => `
        <option value="${p.id}" ${p.id == entry.period_id ? 'selected' : ''}>P${p.period_number}: ${escapeHtml(p.name)} (${escapeHtml(p.start_time)}–${escapeHtml(p.end_time)})</option>
    `).join('');

    const body = `
        <form id="moveTimetableForm">
            <p class="text-muted mb-3">Move <strong>${escapeHtml(entry.subject_code || '')}</strong> slot to a different day and period.</p>
            <div class="form-group">
                <label>Target Day of Week *</label>
                <select id="moveTargetDay" class="form-control" required>
                    ${dayOptions}
                </select>
            </div>
            <div class="form-group">
                <label>Target Period Slot *</label>
                <select id="moveTargetPeriod" class="form-control" required>
                    ${periodOptions}
                </select>
            </div>
            <button type="submit" class="btn btn-primary btn-block mt-3"><i class="fa-solid fa-arrows-up-down-left-right"></i> Move Slot</button>
        </form>
    `;

    openAdminModal("Move Timetable Slot", body);

    document.getElementById('moveTimetableForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const payload = {
            target_day_of_week: document.getElementById('moveTargetDay').value,
            target_period_id: parseInt(document.getElementById('moveTargetPeriod').value)
        };

        try {
            await apiFetch(`/api/v1/admin/timetable/${entryId}/move`, { method: 'POST', body: JSON.stringify(payload) });
            showToast("Timetable slot moved successfully", "success");
            closeAdminModal();
            renderTimetableGrid();
        } catch (err) {
            showToast(err.message || "Failed to move slot. Slot may already be occupied.", "danger");
        }
    });
}

async function openDuplicateTimetableModal(entryId) {
    const entry = cachedTimetable.find(t => t.id === entryId);
    if (!entry) return;

    const periods = cachedPeriods || [];
    const dayOptions = WEEKDAYS.map(d => `<option value="${d}">${d}</option>`).join('');
    const periodOptions = periods.sort((a, b) => a.period_number - b.period_number).map(p => `
        <option value="${p.id}">P${p.period_number}: ${escapeHtml(p.name)} (${escapeHtml(p.start_time)}–${escapeHtml(p.end_time)})</option>
    `).join('');

    const body = `
        <form id="dupTimetableForm">
            <p class="text-muted mb-3">Copy <strong>${escapeHtml(entry.subject_code || '')}</strong> (Faculty: ${escapeHtml(entry.faculty_name || 'Pending')}) into an additional day & period slot.</p>
            <div class="form-group">
                <label>Target Day of Week *</label>
                <select id="dupTargetDay" class="form-control" required>
                    ${dayOptions}
                </select>
            </div>
            <div class="form-group">
                <label>Target Period Slot *</label>
                <select id="dupTargetPeriod" class="form-control" required>
                    ${periodOptions}
                </select>
            </div>
            <button type="submit" class="btn btn-success btn-block mt-3"><i class="fa-solid fa-copy"></i> Duplicate Slot</button>
        </form>
    `;

    openAdminModal("Duplicate Timetable Slot", body);

    document.getElementById('dupTimetableForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const payload = {
            target_day_of_week: document.getElementById('dupTargetDay').value,
            target_period_id: parseInt(document.getElementById('dupTargetPeriod').value)
        };

        try {
            await apiFetch(`/api/v1/admin/timetable/${entryId}/duplicate`, { method: 'POST', body: JSON.stringify(payload) });
            showToast("Timetable slot duplicated successfully", "success");
            closeAdminModal();
            renderTimetableGrid();
        } catch (err) {
            showToast(err.message || "Failed to duplicate slot. Target slot may already be occupied.", "danger");
        }
    });
}

async function confirmDeleteTimetableEntry(id) {
    if (!confirm("Are you sure you want to remove/clear this timetable slot?")) return;
    try {
        await apiFetch(`/api/v1/admin/timetable/${id}`, { method: 'DELETE' });
        showToast("Timetable slot removed", "success");
        renderTimetableGrid();
    } catch (err) {
        showToast(err.message || "Failed to delete timetable entry", "danger");
    }
}

async function confirmResetDevTimetable() {
    const select = document.getElementById('timetableClassSelect');
    const selectedClassId = select ? select.value : '';
    const selectedClassName = select && select.options[select.selectedIndex] ? select.options[select.selectedIndex].text : 'the selected class';

    const confirmed = confirm(
        `RESET DEVELOPMENT TIMETABLE:\n\n` +
        `Are you sure you want to reset the timetable for ${selectedClassName} to the temporary development schedule (42 periods Monday–Saturday)?\n\n` +
        `This will restore temporary faculty assignments and slots. Existing attendance records will remain preserved.`
    );
    if (!confirmed) return;

    try {
        const url = selectedClassId ? `/api/v1/admin/timetable/reset-dev?class_id=${selectedClassId}` : '/api/v1/admin/timetable/reset-dev';
        const res = await apiFetch(url, { method: 'POST' });
        showToast(res.message || "Development timetable reset complete", "success");
        loadTimetableTab();
    } catch (err) {
        showToast(err.message || "Failed to reset development timetable", "danger");
    }
}


function openCreatePeriodModal() {
    const body = `
        <form id="createPeriodForm">
            <div class="form-group">
                <label>Period Number *</label>
                <input type="number" id="pNum" class="form-control" required min="1" max="20" placeholder="1">
            </div>
            <div class="form-group">
                <label>Period Name *</label>
                <input type="text" id="pName" class="form-control" required placeholder="Period 1">
            </div>
            <div class="form-row-2">
                <div class="form-group">
                    <label>Start Time (HH:MM) *</label>
                    <input type="text" id="pStart" class="form-control" required placeholder="09:10">
                </div>
                <div class="form-group">
                    <label>End Time (HH:MM) *</label>
                    <input type="text" id="pEnd" class="form-control" required placeholder="10:00">
                </div>
            </div>
            <button type="submit" class="btn btn-primary btn-block mt-3">Add Period</button>
        </form>
    `;
    openAdminModal("Add Period Timing", body);

    document.getElementById('createPeriodForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const payload = {
            period_number: parseInt(document.getElementById('pNum').value),
            name: document.getElementById('pName').value.trim(),
            start_time: document.getElementById('pStart').value.trim(),
            end_time: document.getElementById('pEnd').value.trim()
        };

        try {
            await apiFetch('/api/v1/admin/periods', { method: 'POST', body: JSON.stringify(payload) });
            showToast("Period added successfully", "success");
            closeAdminModal();
            loadTimetableTab();
        } catch (err) {
            showToast(err.message || "Period timing overlaps with existing period", "danger");
        }
    });
}

async function deletePeriod(id) {
    if (!confirm("Are you sure you want to delete this period?")) return;
    try {
        await apiFetch(`/api/v1/admin/periods/${id}`, { method: 'DELETE' });
        showToast("Period deleted", "success");
        loadTimetableTab();
    } catch (err) {
        showToast(err.message || "Failed to delete period", "danger");
    }
}

// ----------------------------------------------------
// TAB 6: FACULTY ASSIGNMENTS
// ----------------------------------------------------
let cachedAssignmentsList = [];
let assignmentFiltersInitialized = false;

async function loadAssignmentsTab() {
    try {
        const tbody = document.querySelector('#assignmentsTable tbody');
        tbody.innerHTML = '<tr><td colspan="5" class="text-center text-muted"><i class="fa-solid fa-spinner fa-spin me-2"></i> Loading assignments...</td></tr>';

        // Load assignments and filter options in parallel
        const [assignments, classes, subjects, faculty] = await Promise.all([
            apiFetch('/api/v1/admin/assignments'),
            apiFetch('/api/v1/admin/classes'),
            apiFetch('/api/v1/admin/subjects'),
            apiFetch('/api/v1/admin/faculty')
        ]);

        cachedAssignmentsList = assignments || [];

        // Initialize filter dropdowns
        populateAssignmentFilterDropdowns(classes, subjects, faculty);

        if (!assignmentFiltersInitialized) {
            setupAssignmentFilterListeners();
            assignmentFiltersInitialized = true;
        }

        renderAssignmentsTable();
    } catch (e) {
        showToast("Failed to load faculty assignments: " + (e.message || e), "danger");
        const tbody = document.querySelector('#assignmentsTable tbody');
        if (tbody) {
            tbody.innerHTML = '<tr><td colspan="5" class="text-center text-danger">Failed to load assignments. Please click Refresh.</td></tr>';
        }
    }
}

function populateAssignmentFilterDropdowns(classes, subjects, faculty) {
    const classSel = document.getElementById('assignmentClassFilter');
    const subSel = document.getElementById('assignmentSubjectFilter');
    const facSel = document.getElementById('assignmentFacultyFilter');

    if (classSel && classSel.options.length <= 1) {
        classes.forEach(c => {
            const opt = document.createElement('option');
            opt.value = c.id;
            opt.textContent = c.name;
            classSel.appendChild(opt);
        });
    }

    if (subSel && subSel.options.length <= 1) {
        subjects.forEach(s => {
            const opt = document.createElement('option');
            opt.value = s.id;
            opt.textContent = `${s.code} - ${s.name}`;
            subSel.appendChild(opt);
        });
    }

    if (facSel && facSel.options.length <= 1) {
        faculty.forEach(f => {
            const opt = document.createElement('option');
            opt.value = f.id;
            opt.textContent = `${f.full_name} (${f.employee_id})`;
            facSel.appendChild(opt);
        });
    }
}

function setupAssignmentFilterListeners() {
    const searchInput = document.getElementById('assignmentSearch');
    const classSel = document.getElementById('assignmentClassFilter');
    const subSel = document.getElementById('assignmentSubjectFilter');
    const facSel = document.getElementById('assignmentFacultyFilter');
    const statusSel = document.getElementById('assignmentStatusFilter');

    if (searchInput) searchInput.addEventListener('input', () => renderAssignmentsTable());
    if (classSel) classSel.addEventListener('change', () => renderAssignmentsTable());
    if (subSel) subSel.addEventListener('change', () => renderAssignmentsTable());
    if (facSel) facSel.addEventListener('change', () => renderAssignmentsTable());
    if (statusSel) statusSel.addEventListener('change', () => renderAssignmentsTable());
}

function renderAssignmentsTable() {
    const tbody = document.querySelector('#assignmentsTable tbody');
    if (!tbody) return;

    const searchTerm = (document.getElementById('assignmentSearch')?.value || '').trim().toLowerCase();
    const classFilter = document.getElementById('assignmentClassFilter')?.value;
    const subFilter = document.getElementById('assignmentSubjectFilter')?.value;
    const facFilter = document.getElementById('assignmentFacultyFilter')?.value;
    const statusFilter = document.getElementById('assignmentStatusFilter')?.value;

    let filtered = cachedAssignmentsList.filter(a => {
        if (classFilter && String(a.class_id) !== String(classFilter)) return false;
        if (subFilter && String(a.subject_id) !== String(subFilter)) return false;
        if (facFilter) {
            const facIdInt = parseInt(facFilter);
            const isPrimary = a.faculty_id === facIdInt;
            const isSecondary = a.authorized_faculty_ids && a.authorized_faculty_ids.includes(facIdInt);
            if (!isPrimary && !isSecondary) return false;
        }
        if (statusFilter !== '') {
            const isAssn = !!(a.faculty_id || (a.authorized_faculty_ids && a.authorized_faculty_ids.length > 0));
            if (statusFilter === 'true' && !isAssn) return false;
            if (statusFilter === 'false' && isAssn) return false;
        }
        if (searchTerm) {
            const corpus = [
                a.class_name,
                a.subject_code,
                a.subject_name,
                a.faculty_name,
                a.primary_faculty_name,
                ...(a.authorized_faculty_names || [])
            ].filter(Boolean).join(' ').toLowerCase();
            if (!corpus.includes(searchTerm)) return false;
        }
        return true;
    });

    if (filtered.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" class="text-center text-muted py-4">No matching faculty assignments found.</td></tr>';
        return;
    }

    let html = '';
    filtered.forEach(a => {
        const clsName = a.class_name || `Class #${a.class_id}`;
        const subCode = a.subject_code || `Sub #${a.subject_id}`;
        const subName = a.subject_name || '-';
        const isAssigned = !!(a.faculty_id || (a.authorized_faculty_ids && a.authorized_faculty_ids.length > 0));

        let facBadgeHtml = '';
        if (isAssigned) {
            const primaryName = a.primary_faculty_name || a.faculty_name || 'Assigned';
            facBadgeHtml = `<span class="badge badge-success"><i class="fa-solid fa-user-check me-1"></i> ${escapeHtml(primaryName)}</span>`;

            // Display co-faculty badges if present
            if (a.authorized_faculty_names && a.authorized_faculty_names.length > 0) {
                a.authorized_faculty_names.forEach((coName, idx) => {
                    const coId = a.authorized_faculty_ids[idx];
                    if (coId !== a.faculty_id) {
                        facBadgeHtml += ` <span class="badge badge-info ms-1" title="Co-Faculty"><i class="fa-solid fa-users me-1"></i> ${escapeHtml(coName)}</span>`;
                    }
                });
            }
        } else {
            facBadgeHtml = `<span class="badge badge-warning"><i class="fa-solid fa-triangle-exclamation me-1"></i> Unassigned</span>`;
        }

        let actionButtons = '';
        if (!isAssigned) {
            actionButtons = `
                <button class="btn btn-sm btn-success me-1" title="Assign Faculty" onclick="openAssignFacultyModalFor(${a.class_id}, ${a.subject_id}, ${a.id})">
                    <i class="fa-solid fa-user-plus me-1"></i> Assign Faculty
                </button>
                <button class="btn btn-sm btn-outline-primary me-1" title="Edit Assignment" onclick="openEditAssignmentModal(${a.id})">
                    <i class="fa-solid fa-pen"></i>
                </button>
                <button class="btn btn-sm btn-outline-danger" title="Remove Assignment" onclick="openDeleteAssignmentModal(${a.id})">
                    <i class="fa-solid fa-trash"></i>
                </button>
            `;
        } else {
            actionButtons = `
                <button class="btn btn-sm btn-outline-primary me-1" title="Edit / Reassign Faculty" onclick="openEditAssignmentModal(${a.id})">
                    <i class="fa-solid fa-pen me-1"></i> Edit
                </button>
                <button class="btn btn-sm btn-outline-danger" title="Remove Assignment" onclick="openDeleteAssignmentModal(${a.id})">
                    <i class="fa-solid fa-trash"></i>
                </button>
            `;
        }

        html += `
            <tr>
                <td><strong>${escapeHtml(clsName)}</strong></td>
                <td><span class="badge badge-primary">${escapeHtml(subCode)}</span></td>
                <td>${escapeHtml(subName)}</td>
                <td>${facBadgeHtml}</td>
                <td>${actionButtons}</td>
            </tr>
        `;
    });

    tbody.innerHTML = html;
}

function openAssignFacultyModalFor(classId, subjectId, assignmentId) {
    openAssignFacultyModal(classId, subjectId, assignmentId);
}

async function openAssignFacultyModal(preClassId = null, preSubjectId = null, preAssignmentId = null) {
    try {
        const [classes, subjects, faculty] = await Promise.all([
            apiFetch('/api/v1/admin/classes'),
            apiFetch('/api/v1/admin/subjects'),
            apiFetch('/api/v1/admin/faculty')
        ]);

        const classOpts = classes.map(c => `
            <option value="${c.id}" ${preClassId && String(preClassId) === String(c.id) ? 'selected' : ''}>
                ${escapeHtml(c.name)}
            </option>
        `).join('');

        const subOpts = subjects.map(s => `
            <option value="${s.id}" ${preSubjectId && String(preSubjectId) === String(s.id) ? 'selected' : ''}>
                ${escapeHtml(s.code)} - ${escapeHtml(s.name)}
            </option>
        `).join('');

        const activeFaculty = faculty.filter(f => f.is_active !== false);
        const facOpts = activeFaculty.map(f => `
            <option value="${f.id}">${escapeHtml(f.full_name)} (${escapeHtml(f.employee_id)})</option>
        `).join('');

        const coFacBoxes = activeFaculty.map(f => `
            <label class="form-check-label me-3 mb-2" style="display: inline-block;">
                <input type="checkbox" class="form-check-input co-fac-check" value="${f.id}">
                ${escapeHtml(f.full_name)}
            </label>
        `).join('');

        const body = `
            <form id="assignFacForm">
                <div class="form-group mb-3">
                    <label class="form-label"><strong>Class Section *</strong></label>
                    <select id="asClass" class="form-control" required ${preClassId ? 'disabled' : ''}>
                        <option value="">Select Class Section</option>
                        ${classOpts}
                    </select>
                    ${preClassId ? `<input type="hidden" id="asClassHidden" value="${preClassId}">` : ''}
                </div>
                <div class="form-group mb-3">
                    <label class="form-label"><strong>Subject *</strong></label>
                    <select id="asSub" class="form-control" required ${preSubjectId ? 'disabled' : ''}>
                        <option value="">Select Subject</option>
                        ${subOpts}
                    </select>
                    ${preSubjectId ? `<input type="hidden" id="asSubHidden" value="${preSubjectId}">` : ''}
                </div>
                <div class="form-group mb-3">
                    <label class="form-label"><strong>Primary Assigned Faculty *</strong></label>
                    <select id="asFac" class="form-control" required>
                        <option value="">Select Faculty Member</option>
                        ${facOpts}
                    </select>
                </div>
                <div class="form-group mb-3">
                    <label class="form-label"><strong>Additional Co-Faculty (Optional)</strong></label>
                    <div class="border rounded p-2" style="max-height: 120px; overflow-y: auto; background: rgba(0,0,0,0.15);">
                        ${coFacBoxes}
                    </div>
                    <small class="text-muted">Select multiple faculty members for shared or laboratory subjects.</small>
                </div>
                <div class="d-flex justify-content-end gap-2 mt-4">
                    <button type="button" class="btn btn-outline-secondary" onclick="closeAdminModal()">Cancel</button>
                    <button type="submit" class="btn btn-success"><i class="fa-solid fa-check me-1"></i> Assign Faculty</button>
                </div>
            </form>
        `;

        openAdminModal(preAssignmentId ? "Assign Faculty to Subject" : "New Faculty Assignment", body);

        document.getElementById('assignFacForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const facId = parseInt(document.getElementById('asFac').value);
            if (!facId) {
                showToast("Please select a primary faculty member", "danger");
                return;
            }

            const classIdVal = preClassId || document.getElementById('asClass').value;
            const subIdVal = preSubjectId || document.getElementById('asSub').value;

            if (!classIdVal || !subIdVal) {
                showToast("Please select both class and subject", "danger");
                return;
            }

            // Gather selected co-faculty
            const coFacIds = [];
            document.querySelectorAll('.co-fac-check:checked').forEach(cb => {
                const idVal = parseInt(cb.value);
                if (idVal && !coFacIds.includes(idVal)) coFacIds.push(idVal);
            });
            // Ensure primary faculty is included in authorized list
            if (!coFacIds.includes(facId)) coFacIds.push(facId);

            const payload = {
                class_id: parseInt(classIdVal),
                subject_id: parseInt(subIdVal),
                faculty_id: facId,
                authorized_faculty_ids: coFacIds
            };

            try {
                if (preAssignmentId) {
                    await apiFetch(`/api/v1/admin/assignments/${preAssignmentId}`, {
                        method: 'PUT',
                        body: JSON.stringify(payload)
                    });
                    showToast("Faculty assigned successfully", "success");
                } else {
                    await apiFetch('/api/v1/admin/assignments', {
                        method: 'POST',
                        body: JSON.stringify(payload)
                    });
                    showToast("Faculty assignment created successfully", "success");
                }
                closeAdminModal();
                loadAssignmentsTab();
            } catch (err) {
                showToast(err.message || "Failed to assign faculty", "danger");
            }
        });
    } catch (e) {
        showToast("Failed to load options for assignment: " + (e.message || e), "danger");
    }
}

async function openEditAssignmentModal(assignmentId) {
    try {
        const assignment = cachedAssignmentsList.find(a => a.id === assignmentId);
        if (!assignment) {
            showToast("Assignment not found", "danger");
            return;
        }

        const [classes, subjects, faculty] = await Promise.all([
            apiFetch('/api/v1/admin/classes'),
            apiFetch('/api/v1/admin/subjects'),
            apiFetch('/api/v1/admin/faculty')
        ]);

        const classOpts = classes.map(c => `
            <option value="${c.id}" ${assignment.class_id === c.id ? 'selected' : ''}>${escapeHtml(c.name)}</option>
        `).join('');

        const subOpts = subjects.map(s => `
            <option value="${s.id}" ${assignment.subject_id === s.id ? 'selected' : ''}>${escapeHtml(s.code)} - ${escapeHtml(s.name)}</option>
        `).join('');

        const activeFaculty = faculty.filter(f => f.is_active !== false);
        const facOpts = activeFaculty.map(f => `
            <option value="${f.id}" ${assignment.faculty_id === f.id ? 'selected' : ''}>${escapeHtml(f.full_name)} (${escapeHtml(f.employee_id)})</option>
        `).join('');

        const currentAuthIds = assignment.authorized_faculty_ids || [];
        const coFacBoxes = activeFaculty.map(f => `
            <label class="form-check-label me-3 mb-2" style="display: inline-block;">
                <input type="checkbox" class="form-check-input edit-co-fac-check" value="${f.id}" ${currentAuthIds.includes(f.id) ? 'checked' : ''}>
                ${escapeHtml(f.full_name)}
            </label>
        `).join('');

        const body = `
            <form id="editFacForm">
                <div class="form-group mb-3">
                    <label class="form-label"><strong>Class Section *</strong></label>
                    <select id="editAsClass" class="form-control" required>
                        ${classOpts}
                    </select>
                </div>
                <div class="form-group mb-3">
                    <label class="form-label"><strong>Subject *</strong></label>
                    <select id="editAsSub" class="form-control" required>
                        ${subOpts}
                    </select>
                </div>
                <div class="form-group mb-3">
                    <label class="form-label"><strong>Primary Assigned Faculty</strong></label>
                    <select id="editAsFac" class="form-control">
                        <option value="">-- Unassigned (Pending) --</option>
                        ${facOpts}
                    </select>
                    <small class="text-muted">Select a faculty member or leave as Unassigned.</small>
                </div>
                <div class="form-group mb-3">
                    <label class="form-label"><strong>Additional Co-Faculty</strong></label>
                    <div class="border rounded p-2" style="max-height: 120px; overflow-y: auto; background: rgba(0,0,0,0.15);">
                        ${coFacBoxes}
                    </div>
                </div>
                ${assignment.timetable_count > 0 ? `
                    <div class="alert alert-info py-2 small mb-3">
                        <i class="fa-solid fa-calendar-days me-1"></i>
                        This assignment is referenced by <strong>${assignment.timetable_count} timetable slot(s)</strong>. Timetable entries will automatically reflect the updated faculty.
                    </div>
                ` : ''}
                <div class="d-flex justify-content-end gap-2 mt-4">
                    <button type="button" class="btn btn-outline-secondary" onclick="closeAdminModal()">Cancel</button>
                    <button type="submit" class="btn btn-primary"><i class="fa-solid fa-floppy-disk me-1"></i> Save Changes</button>
                </div>
            </form>
        `;

        openAdminModal(`Edit Faculty Assignment — ${escapeHtml(assignment.subject_code || '')}`, body);

        document.getElementById('editFacForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const facVal = document.getElementById('editAsFac').value;
            const facId = facVal ? parseInt(facVal) : null;

            const coFacIds = [];
            document.querySelectorAll('.edit-co-fac-check:checked').forEach(cb => {
                const idVal = parseInt(cb.value);
                if (idVal && !coFacIds.includes(idVal)) coFacIds.push(idVal);
            });
            if (facId && !coFacIds.includes(facId)) coFacIds.push(facId);

            const payload = {
                class_id: parseInt(document.getElementById('editAsClass').value),
                subject_id: parseInt(document.getElementById('editAsSub').value),
                faculty_id: facId,
                authorized_faculty_ids: coFacIds
            };

            try {
                await apiFetch(`/api/v1/admin/assignments/${assignmentId}`, {
                    method: 'PUT',
                    body: JSON.stringify(payload)
                });
                showToast("Assignment updated successfully", "success");
                closeAdminModal();
                loadAssignmentsTab();
            } catch (err) {
                showToast(err.message || "Failed to update assignment", "danger");
            }
        });
    } catch (e) {
        showToast("Failed to load assignment details: " + (e.message || e), "danger");
    }
}

function openDeleteAssignmentModal(assignmentId) {
    const assignment = cachedAssignmentsList.find(a => a.id === assignmentId);
    if (!assignment) {
        showToast("Assignment not found", "danger");
        return;
    }

    const clsName = assignment.class_name || `Class #${assignment.class_id}`;
    const subCode = assignment.subject_code || `Sub #${assignment.subject_id}`;
    const subName = assignment.subject_name || '-';
    const facName = assignment.faculty_name || 'Unassigned';
    const ttCount = assignment.timetable_count || 0;

    const body = `
        <div class="mb-3">
            <p>Are you sure you want to remove this faculty-subject assignment?</p>
            <div class="panel-card p-3 my-3" style="background: rgba(0,0,0,0.25);">
                <div class="mb-2"><strong>Class:</strong> ${escapeHtml(clsName)}</div>
                <div class="mb-2"><strong>Subject:</strong> <span class="badge badge-primary">${escapeHtml(subCode)}</span> ${escapeHtml(subName)}</div>
                <div class="mb-2"><strong>Assigned Faculty:</strong> ${escapeHtml(facName)}</div>
                <div><strong>Timetable Slots:</strong> <span class="badge ${ttCount > 0 ? 'badge-warning' : 'badge-secondary'}">${ttCount} slot(s)</span></div>
            </div>
            ${ttCount > 0 ? `
                <div class="alert alert-warning small py-2 mb-3">
                    <i class="fa-solid fa-triangle-exclamation me-1"></i>
                    <strong>Referential Safety Rule:</strong> Deleting an assignment with active timetable slots or class sessions is guarded by referential integrity. If historical attendance records exist, deletion is safely blocked.
                </div>
            ` : ''}
        </div>
        <div class="d-flex justify-content-end gap-2">
            <button type="button" class="btn btn-outline-secondary" onclick="closeAdminModal()">Cancel</button>
            <button type="button" class="btn btn-danger" onclick="executeDeleteAssignment(${assignmentId})">
                <i class="fa-solid fa-trash me-1"></i> Remove Assignment
            </button>
        </div>
    `;

    openAdminModal("Remove Faculty Assignment", body);
}

async function executeDeleteAssignment(assignmentId) {
    try {
        await apiFetch(`/api/v1/admin/assignments/${assignmentId}`, { method: 'DELETE' });
        showToast("Faculty assignment removed successfully", "success");
        closeAdminModal();
        loadAssignmentsTab();
    } catch (err) {
        showToast(err.message || "Failed to delete assignment", "danger");
    }
}

// ----------------------------------------------------
// TAB 7: POLICY & SYSTEM SETTINGS
// ----------------------------------------------------
async function loadSettingsTab() {
    try {
        const [policy, authSys, aiSys] = await Promise.all([
            apiFetch('/api/v1/admin/settings/attendance-policy'),
            apiFetch('/api/v1/admin/settings/auth'),
            apiFetch('/api/v1/admin/settings/ai')
        ]);

        // Policy Form
        document.getElementById('policyMinPct').value = policy.minimum_percentage != null ? policy.minimum_percentage : 75.0;
        
        // Strict mapping: only 'RECORD_BASED' or 'IMPACT_BASED'
        const validCalcModes = ['RECORD_BASED', 'IMPACT_BASED'];
        const calcMode = validCalcModes.includes(policy.calculation_mode) ? policy.calculation_mode : 'RECORD_BASED';
        const calcModeSelect = document.getElementById('policyCalcMode');
        if (calcModeSelect) {
            calcModeSelect.value = calcMode;
        }

        document.getElementById('policyPeriodLoss').value = policy.period_absent_loss != null ? policy.period_absent_loss : 0.5;
        document.getElementById('policyClassLoss').value = policy.class_absent_loss != null ? policy.class_absent_loss : 1.0;
        document.getElementById('policyDayLoss').value = policy.day_absent_loss != null ? policy.day_absent_loss : 2.0;
        document.getElementById('policyAllowOD').checked = !!policy.allow_od_marking;
        document.getElementById('policyODPresent').checked = !!policy.od_counts_as_present;

        // System Auth
        document.getElementById('settingFacultyAuth').value = authSys['auth.faculty_login_method'] || 'USERNAME';
        document.getElementById('settingStudentAuth').value = authSys['auth.student_login_method'] || 'REGISTER_NUMBER';
        document.getElementById('settingMaxFailed').value = authSys['auth.max_failed_attempts'] != null ? authSys['auth.max_failed_attempts'] : 5;
        document.getElementById('settingLockMins').value = authSys['auth.lock_duration_minutes'] != null ? authSys['auth.lock_duration_minutes'] : 30;

        // System AI
        document.getElementById('settingAIThreshold').value = aiSys['ai.recognition_threshold'] != null ? aiSys['ai.recognition_threshold'] : 0.45;
        const validPerfModes = ['BALANCED', 'ACCURACY', 'SPEED'];
        const perfMode = validPerfModes.includes(aiSys['ai.performance_mode']) ? aiSys['ai.performance_mode'] : 'BALANCED';
        document.getElementById('settingAIPerf').value = perfMode;

    } catch (e) {
        showToast("Failed to load system settings", "danger");
    }
}

let isSavingPolicy = false;
async function handleSavePolicy(e) {
    e.preventDefault();
    if (isSavingPolicy) return;
    isSavingPolicy = true;

    const submitBtn = e.target.querySelector('button[type="submit"]');
    const origHtml = submitBtn ? submitBtn.innerHTML : '';
    if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Saving...';
    }

    try {
        const calcModeSelect = document.getElementById('policyCalcMode');
        const calcModeVal = calcModeSelect ? calcModeSelect.value : 'RECORD_BASED';
        const calculation_mode = (calcModeVal === 'IMPACT_BASED') ? 'IMPACT_BASED' : 'RECORD_BASED';

        const payload = {
            minimum_percentage: parseFloat(document.getElementById('policyMinPct').value) || 75.0,
            calculation_mode: calculation_mode,
            period_absent_loss: parseFloat(document.getElementById('policyPeriodLoss').value) || 0.0,
            class_absent_loss: parseFloat(document.getElementById('policyClassLoss').value) || 0.0,
            day_absent_loss: parseFloat(document.getElementById('policyDayLoss').value) || 0.0,
            allow_od_marking: document.getElementById('policyAllowOD').checked,
            od_counts_as_present: document.getElementById('policyODPresent').checked
        };

        const updated = await apiFetch('/api/v1/admin/settings/attendance-policy', {
            method: 'PUT',
            body: JSON.stringify(payload)
        });

        if (calcModeSelect && updated.calculation_mode) {
            calcModeSelect.value = updated.calculation_mode;
        }

        showToast("Attendance policy updated successfully", "success");
    } catch (err) {
        showToast(err.message || "Failed to update policy", "danger");
    } finally {
        isSavingPolicy = false;
        if (submitBtn) {
            submitBtn.disabled = false;
            submitBtn.innerHTML = origHtml;
        }
    }
}

let isSavingSystem = false;
async function handleSaveSystemSettings(e) {
    e.preventDefault();
    if (isSavingSystem) return;
    isSavingSystem = true;

    const submitBtn = e.target.querySelector('button[type="submit"]');
    const origHtml = submitBtn ? submitBtn.innerHTML : '';
    if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Saving...';
    }

    try {
        const authPayload = {
            "auth.faculty_login_method": document.getElementById('settingFacultyAuth').value.trim(),
            "auth.student_login_method": document.getElementById('settingStudentAuth').value.trim(),
            "auth.max_failed_attempts": parseInt(document.getElementById('settingMaxFailed').value) || 5,
            "auth.lock_duration_minutes": parseInt(document.getElementById('settingLockMins').value) || 30
        };

        const perfSelect = document.getElementById('settingAIPerf');
        const perfVal = perfSelect ? perfSelect.value : 'BALANCED';
        const performance_mode = ['BALANCED', 'ACCURACY', 'SPEED'].includes(perfVal) ? perfVal : 'BALANCED';

        const aiPayload = {
            "ai.recognition_threshold": parseFloat(document.getElementById('settingAIThreshold').value) || 0.45,
            "ai.performance_mode": performance_mode
        };

        await Promise.all([
            apiFetch('/api/v1/admin/settings/auth', { method: 'PUT', body: JSON.stringify(authPayload) }),
            apiFetch('/api/v1/admin/settings/ai', { method: 'PUT', body: JSON.stringify(aiPayload) })
        ]);
        showToast("System & AI settings saved successfully", "success");
    } catch (err) {
        showToast(err.message || "Failed to save system settings", "danger");
    } finally {
        isSavingSystem = false;
        if (submitBtn) {
            submitBtn.disabled = false;
            submitBtn.innerHTML = origHtml;
        }
    }
}

// ----------------------------------------------------
// TAB 8: BULK IMPORT
// ----------------------------------------------------
async function triggerSeedImport() {
    if (!confirm("Import official II Year CSE Cyber Security college seed bundle from college_seed/?")) return;
    try {
        const res = await apiFetch('/api/v1/admin/import/college-seed', { method: 'POST' });
        showToast("Official college seed imported!", "success");
        displayImportResults(res);
    } catch (err) {
        showToast(err.message || "Failed to import college seed", "danger");
    }
}

async function submitImport(type) {
    let inputId = '';
    let url = '';
    if (type === 'students') { inputId = 'importStudentsJSON'; url = '/api/v1/admin/import/students'; }
    else if (type === 'faculty') { inputId = 'importFacultyJSON'; url = '/api/v1/admin/import/faculty'; }
    else if (type === 'subjects') { inputId = 'importSubjectsJSON'; url = '/api/v1/admin/import/subjects'; }

    const raw = document.getElementById(inputId).value.trim();
    if (!raw) { showToast("Please paste JSON import array", "danger"); return; }

    try {
        const parsed = JSON.parse(raw);
        const res = await apiFetch(url, { method: 'POST', body: JSON.stringify(parsed) });
        showToast("Import operation finished", "success");
        displayImportResults(res);
    } catch (err) {
        showToast(err.message || "JSON parsing or import failed", "danger");
    }
}

function displayImportResults(data) {
    const box = document.getElementById('importResultsBox');
    const display = document.getElementById('importResultJSON');
    box.classList.remove('hidden');
    display.innerText = JSON.stringify(data, null, 2);
}

// ----------------------------------------------------
// TAB 9: AUDIT LOGS
// ----------------------------------------------------
async function loadAuditLogs() {
    try {
        const logs = await apiFetch('/api/v1/admin/audit?limit=50');
        const tbody = document.querySelector('#auditTable tbody');
        if (!logs || logs.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" class="text-center text-muted">No audit events found.</td></tr>';
            return;
        }

        tbody.innerHTML = logs.map(l => `
            <tr>
                <td>#${l.id}</td>
                <td>${formatDate(l.timestamp)}</td>
                <td>User #${l.user_id}</td>
                <td><span class="badge badge-primary">${escapeHtml(l.action)}</span></td>
                <td class="small">${escapeHtml(l.details)}</td>
            </tr>
        `).join('');
    } catch (e) {
        showToast("Failed to load audit trail", "danger");
    }
}

// Modal Helpers
function openAdminModal(title, bodyHtml) {
    document.getElementById('modalTitle').innerText = title;
    document.getElementById('modalBody').innerHTML = bodyHtml;
    document.getElementById('adminModal').classList.remove('hidden');
}

function closeAdminModal() {
    document.getElementById('adminModal').classList.add('hidden');
}

// Utilities
function escapeHtml(str) {
    if (!str) return '';
    return String(str).replace(/[&<>"']/g, function(m) {
        return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' }[m];
    });
}

function formatDate(isoStr) {
    if (!isoStr) return '-';
    try {
        const d = new Date(isoStr);
        return d.toLocaleString();
    } catch (e) { return isoStr; }
}


// ----------------------------------------------------
// TAB 10: PASSWORD CONTROL & WINDOWS
// ----------------------------------------------------
let cachedPasswordWindows = [];

async function loadPasswordControlTab() {
    try {
        const [stats, windows] = await Promise.all([
            apiFetch('/api/v1/admin/password-control/stats'),
            apiFetch('/api/v1/admin/password-change-window')
        ]);

        document.getElementById('statStudentsPwChange').innerText = stats.students_requiring_change ?? 0;
        document.getElementById('statFacultyPwChange').innerText = stats.faculty_requiring_change ?? 0;
        document.getElementById('statActivePwWindows').innerText = stats.active_windows_count ?? 0;
        document.getElementById('statTotalPwWindows').innerText = stats.total_windows_count ?? 0;

        cachedPasswordWindows = windows || [];
        renderPasswordWindowsTable();
    } catch (e) {
        showToast("Failed to load password control data", "danger");
    }
}

function renderPasswordWindowsTable() {
    const tbody = document.querySelector('#passwordWindowsTable tbody');
    if (!tbody) return;

    if (cachedPasswordWindows.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" class="text-center text-muted">No password change windows configured.</td></tr>';
        return;
    }

    tbody.innerHTML = cachedPasswordWindows.map(w => {
        const scopeBadgeMap = {
            'ALL_STUDENTS': '<span class="badge badge-info"><i class="fa-solid fa-graduation-cap"></i> All Students</span>',
            'ALL_FACULTY': '<span class="badge badge-primary"><i class="fa-solid fa-chalkboard-user"></i> All Faculty</span>',
            'ALL_USERS': '<span class="badge badge-warning"><i class="fa-solid fa-users"></i> All Users</span>',
            'SELECTED_STUDENTS': '<span class="badge badge-secondary">Selected Students</span>',
            'SELECTED_FACULTY': '<span class="badge badge-secondary">Selected Faculty</span>',
            'SELECTED_ACCOUNTS': '<span class="badge badge-secondary">Selected Accounts</span>'
        };
        const scopeBadge = scopeBadgeMap[w.scope] || `<span class="badge badge-secondary">${w.scope}</span>`;
        const activeBadge = w.is_active
            ? '<span class="badge badge-success"><i class="fa-solid fa-circle-check"></i> Active</span>'
            : '<span class="badge badge-danger"><i class="fa-solid fa-circle-xmark"></i> Inactive</span>';

        const scheduleText = (w.start_at || w.end_at)
            ? `${w.start_at ? formatDate(w.start_at) : 'Immediate'} → ${w.end_at ? formatDate(w.end_at) : 'Indefinite'}`
            : '<span class="text-muted">Always Active</span>';

        const detailsText = w.target_ids ? `<code class="small">${escapeHtml(w.target_ids)}</code>` : '<span class="text-muted">Global Scope</span>';

        return `
            <tr>
                <td><strong>${escapeHtml(w.title)}</strong></td>
                <td>${scopeBadge}</td>
                <td>${detailsText}</td>
                <td class="small">${scheduleText}</td>
                <td>${activeBadge}</td>
                <td><span class="badge badge-secondary">${w.affected_users_count ?? 0}</span></td>
                <td>
                    <div class="btn-group gap-1">
                        <button class="btn btn-sm ${w.is_active ? 'btn-outline-warning' : 'btn-outline-success'}" onclick="togglePasswordWindow(${w.id}, ${!w.is_active})" title="${w.is_active ? 'Deactivate Window' : 'Activate Window'}">
                            <i class="fa-solid ${w.is_active ? 'fa-pause' : 'fa-play'}"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-danger" onclick="deletePasswordWindow(${w.id}, '${escapeHtml(w.title)}')" title="Delete Window">
                            <i class="fa-solid fa-trash"></i>
                        </button>
                    </div>
                </td>
            </tr>
        `;
    }).join('');
}

function openCreatePasswordWindowModal() {
    const body = `
        <form id="createWindowForm">
            <div class="form-group">
                <label>Window Title *</label>
                <input type="text" id="winTitle" class="form-control" required placeholder="e.g. Semester Start Mandatory Password Reset">
            </div>

            <div class="form-group mt-2">
                <label>Target Scope *</label>
                <select id="winScope" class="form-control" onchange="toggleScopeInputs()">
                    <option value="ALL_STUDENTS">All Students</option>
                    <option value="ALL_FACULTY">All Faculty</option>
                    <option value="ALL_USERS">All Users (Students + Faculty)</option>
                    <option value="SELECTED_STUDENTS">Selected Students (by ID / Roll)</option>
                    <option value="SELECTED_FACULTY">Selected Faculty (by ID / Emp ID)</option>
                    <option value="SELECTED_ACCOUNTS">Selected User Accounts (by User ID)</option>
                </select>
            </div>

            <div id="targetIdsGroup" class="form-group mt-2 hidden">
                <label>Target IDs (comma-separated or JSON array) *</label>
                <input type="text" id="winTargetIds" class="form-control" placeholder="e.g. 1, 2, 3 or [1, 2, 3]">
                <small class="text-muted">Specify the IDs for the selected scope</small>
            </div>

            <div class="grid-2-col gap-3 mt-2">
                <div class="form-group">
                    <label>Start At (Optional)</label>
                    <input type="datetime-local" id="winStartAt" class="form-control">
                </div>
                <div class="form-group">
                    <label>End At (Optional)</label>
                    <input type="datetime-local" id="winEndAt" class="form-control">
                </div>
            </div>

            <div class="form-check mt-3">
                <label>
                    <input type="checkbox" id="winIsActive" checked>
                    <strong>Activate Immediately & Enforce Flag</strong>
                </label>
                <p class="text-muted small">When active, all accounts matching the scope will be marked as requiring a password change immediately.</p>
            </div>

            <div class="modal-footer mt-4">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="submit" class="btn btn-primary"><i class="fa-solid fa-save"></i> Create & Apply Window</button>
            </div>
        </form>
    `;
    openAdminModal("Create Password Change Window", body);

    document.getElementById('createWindowForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const title = document.getElementById('winTitle').value.trim();
        const scope = document.getElementById('winScope').value;
        const targetIdsRaw = document.getElementById('winTargetIds').value.trim();
        const startAt = document.getElementById('winStartAt').value || null;
        const endAt = document.getElementById('winEndAt').value || null;
        const isActive = document.getElementById('winIsActive').checked;

        let target_ids = null;
        if (targetIdsRaw) {
            try {
                target_ids = JSON.parse(targetIdsRaw);
            } catch (err) {
                target_ids = targetIdsRaw.split(',').map(s => s.trim()).filter(Boolean);
            }
        }

        try {
            await apiFetch('/api/v1/admin/password-change-window', {
                method: 'POST',
                body: JSON.stringify({
                    title,
                    scope,
                    target_ids,
                    start_at: startAt ? new Date(startAt).toISOString() : null,
                    end_at: endAt ? new Date(endAt).toISOString() : null,
                    is_active: isActive
                })
            });
            closeAdminModal();
            showToast("Password change window created and applied successfully!", "success");
            loadPasswordControlTab();
        } catch (err) {
            showToast(err.message || "Failed to create password change window", "danger");
        }
    });
}

function toggleScopeInputs() {
    const scope = document.getElementById('winScope')?.value;
    const group = document.getElementById('targetIdsGroup');
    if (!group) return;
    if (scope && scope.startsWith('SELECTED_')) {
        group.classList.remove('hidden');
    } else {
        group.classList.add('hidden');
    }
}

async function togglePasswordWindow(id, newActiveState) {
    try {
        await apiFetch(`/api/v1/admin/password-change-window/${id}`, {
            method: 'PUT',
            body: JSON.stringify({ is_active: newActiveState })
        });
        showToast(`Window ${newActiveState ? 'activated' : 'deactivated'} successfully`, "success");
        loadPasswordControlTab();
    } catch (e) {
        showToast(e.message || "Failed to update window", "danger");
    }
}

async function deletePasswordWindow(id, title) {
    if (!confirm(`Are you sure you want to delete password change window "${title}"?`)) return;
    try {
        await apiFetch(`/api/v1/admin/password-change-window/${id}`, { method: 'DELETE' });
        showToast("Password change window deleted successfully", "success");
        loadPasswordControlTab();
    } catch (e) {
        showToast(e.message || "Failed to delete window", "danger");
    }
}


// ----------------------------------------------------
// ADMIN SUPPORT-ACCESS / IMPERSONATION MODE
// ----------------------------------------------------
let activeSupportSession = null;
let supportTimerInterval = null;

function promptStartSupportMode(targetType, targetId, targetName) {
    const body = `
        <form id="supportAuthForm">
            <div class="alert alert-info">
                <i class="fa-solid fa-shield-halved"></i>
                <strong>Security Re-Authentication Required:</strong>
                Entering Support Mode creates an audited, short-lived (15 min) read-only inspection session for <strong>${escapeHtml(targetName)}</strong>.
            </div>

            <div class="form-group mt-3">
                <label>Admin Password Confirmation *</label>
                <input type="password" id="adminReauthPassword" class="form-control" required placeholder="Enter your current Admin password" autocomplete="current-password">
                <small class="text-muted">Re-authentication confirms your administrative identity before entering support mode.</small>
            </div>

            <div class="form-group mt-3">
                <label>Support Reason / Ticket ID (Optional)</label>
                <input type="text" id="supportReason" class="form-control" placeholder="e.g. Inspecting timetable conflict, Support ticket #1042">
            </div>

            <div class="modal-footer mt-4">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="submit" class="btn btn-primary"><i class="fa-solid fa-user-secret"></i> Start Support Mode</button>
            </div>
        </form>
    `;
    openAdminModal(`Enter Support Mode: ${targetName}`, body);

    document.getElementById('supportAuthForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const admin_password = document.getElementById('adminReauthPassword').value;
        const reason = document.getElementById('supportReason').value.trim() || undefined;

        const payload = {
            admin_password,
            reason,
            duration_minutes: 15,
            read_only: true
        };

        if (targetType === 'student') {
            payload.target_student_id = targetId;
        } else if (targetType === 'faculty') {
            payload.target_faculty_id = targetId;
        } else {
            payload.target_user_id = targetId;
        }

        try {
            const sess = await apiFetch('/api/v1/admin/support/start', {
                method: 'POST',
                body: JSON.stringify(payload)
            });
            closeAdminModal();
            startSupportClientSession(sess);
            showToast(`Support Mode active for ${sess.target_name} (${sess.target_role})`, "success");
        } catch (err) {
            showToast(err.message || "Failed to start support session. Check admin password.", "danger");
        }
    });
}

function startSupportClientSession(sessionData) {
    activeSupportSession = sessionData;
    sessionStorage.setItem('activeSupportSession', JSON.stringify(sessionData));

    const banner = document.getElementById('supportBanner');
    const desc = document.getElementById('supportTargetDesc');
    if (banner && desc) {
        desc.innerText = `${sessionData.target_name} (${sessionData.target_role} • ${sessionData.target_identifier})`;
        banner.classList.remove('hidden');
    }

    if (supportTimerInterval) clearInterval(supportTimerInterval);
    updateSupportCountdownDisplay();
    supportTimerInterval = setInterval(updateSupportCountdownDisplay, 1000);
}

function updateSupportCountdownDisplay() {
    if (!activeSupportSession) return;
    const expiresAt = new Date(activeSupportSession.expires_at).getTime();
    const now = Date.now();
    const remainingMs = expiresAt - now;

    if (remainingMs <= 0) {
        clearInterval(supportTimerInterval);
        exitSupportMode(true);
        return;
    }

    const totalSecs = Math.floor(remainingMs / 1000);
    const mins = Math.floor(totalSecs / 60);
    const secs = totalSecs % 60;
    const timeStr = `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;

    const timerEl = document.getElementById('supportCountdown');
    if (timerEl) timerEl.innerText = timeStr;
}

async function exitSupportMode(wasExpired = false) {
    if (supportTimerInterval) clearInterval(supportTimerInterval);
    const sess = activeSupportSession;
    activeSupportSession = null;
    sessionStorage.removeItem('activeSupportSession');

    const banner = document.getElementById('supportBanner');
    if (banner) banner.classList.add('hidden');

    if (sess && !wasExpired) {
        try {
            await apiFetch(`/api/v1/admin/support/${sess.session_id}/end`, { method: 'POST' });
        } catch (e) {}
    }

    if (wasExpired) {
        showToast("Support session has expired", "warning");
    } else {
        showToast("Exited Admin Support Mode successfully", "success");
    }
}

async function inspectSupportCurrentTarget() {
    if (!activeSupportSession) return;
    try {
        const data = await apiFetch(`/api/v1/admin/support/${activeSupportSession.session_id}/inspect`);

        let contentHtml = '';
        if (data.role === 'STUDENT') {
            const ttRows = (data.timetable || []).map(t => `
                <tr>
                    <td>Day ${t.day_of_week} (Period ${t.period_id})</td>
                    <td><strong>${escapeHtml(t.subject)}</strong></td>
                    <td>${escapeHtml(t.faculty)}</td>
                </tr>
            `).join('') || '<tr><td colspan="3" class="text-center text-muted">No timetable entries found</td></tr>';

            contentHtml = `
                <div class="profile-card mb-3">
                    <h4><i class="fa-solid fa-user-graduate"></i> Student Profile (Read-Only)</h4>
                    <p><strong>Roll Number:</strong> ${escapeHtml(data.roll_number)}</p>
                    <p><strong>Name:</strong> ${escapeHtml(data.full_name)}</p>
                    <p><strong>Class Section:</strong> ${escapeHtml(data.class_name || 'Unassigned')}</p>
                    <p><strong>Email:</strong> ${escapeHtml(data.email || '—')}</p>
                    <p><strong>Phone:</strong> ${escapeHtml(data.phone || '—')}</p>
                </div>
                <h5><i class="fa-solid fa-calendar-days"></i> Enrolled Timetable Slots (${data.timetable_count})</h5>
                <table class="data-table mt-2">
                    <thead><tr><th>Slot</th><th>Subject</th><th>Faculty</th></tr></thead>
                    <tbody>${ttRows}</tbody>
                </table>
            `;
        } else if (data.role === 'FACULTY') {
            const ttRows = (data.timetable || []).map(t => `
                <tr>
                    <td>Day ${t.day_of_week} (Period ${t.period_id})</td>
                    <td><strong>${escapeHtml(t.subject)}</strong></td>
                    <td>${escapeHtml(t.class_name)}</td>
                </tr>
            `).join('') || '<tr><td colspan="3" class="text-center text-muted">No teaching slots assigned</td></tr>';

            contentHtml = `
                <div class="profile-card mb-3">
                    <h4><i class="fa-solid fa-chalkboard-user"></i> Faculty Profile (Read-Only)</h4>
                    <p><strong>Employee ID:</strong> ${escapeHtml(data.employee_id)}</p>
                    <p><strong>Name:</strong> ${escapeHtml(data.full_name)}</p>
                    <p><strong>Department:</strong> ${escapeHtml(data.department || 'General')}</p>
                    <p><strong>Email:</strong> ${escapeHtml(data.email || '—')}</p>
                </div>
                <h5><i class="fa-solid fa-calendar-days"></i> Assigned Teaching Slots (${data.timetable_count})</h5>
                <table class="data-table mt-2">
                    <thead><tr><th>Slot</th><th>Subject</th><th>Class Section</th></tr></thead>
                    <tbody>${ttRows}</tbody>
                </table>
            `;
        }

        openAdminModal(`Support Mode Inspection: ${activeSupportSession.target_name}`, contentHtml);
    } catch (e) {
        showToast(e.message || "Failed to inspect target account", "danger");
    }
}


// ====================================================
// TAB: ATTENDANCE RECORDS MANAGEMENT
// ====================================================
async function loadAttendanceTab() {
    const tbody = document.querySelector('#attendanceTable tbody');
    if (tbody) {
        tbody.innerHTML = '<tr><td colspan="10" class="text-center text-muted py-4"><i class="fa-solid fa-spinner fa-spin mr-2"></i> Loading attendance records...</td></tr>';
    }

    try {
        if (cachedClasses.length === 0 || cachedSubjects.length === 0) {
            const [classes, subjects] = await Promise.all([
                apiFetch('/api/v1/admin/classes'),
                apiFetch('/api/v1/admin/subjects')
            ]);
            cachedClasses = classes;
            cachedSubjects = subjects;
        }

        const classFilter = document.getElementById('attendanceClassFilter');
        if (classFilter && classFilter.children.length <= 1) {
            classFilter.innerHTML = '<option value="">All Classes</option>' +
                cachedClasses.map(c => `<option value="${c.id}">${escapeHtml(c.name)}</option>`).join('');
        }

        const subFilter = document.getElementById('attendanceSubjectFilter');
        if (subFilter && subFilter.children.length <= 1) {
            subFilter.innerHTML = '<option value="">All Subjects</option>' +
                cachedSubjects.map(s => `<option value="${s.id}">${escapeHtml(s.code)} - ${escapeHtml(s.name)}</option>`).join('');
        }

        const classVal = document.getElementById('attendanceClassFilter')?.value;
        const subVal = document.getElementById('attendanceSubjectFilter')?.value;
        const statusVal = document.getElementById('attendanceStatusFilter')?.value;
        const dateVal = document.getElementById('attendanceDateFilter')?.value;

        const params = new URLSearchParams();
        params.append('limit', '300');
        if (classVal) params.append('class_id', classVal);
        if (subVal) params.append('subject_id', subVal);
        if (statusVal) params.append('status', statusVal);
        if (dateVal) params.append('date', dateVal);

        const records = await apiFetch(`/api/v1/admin/attendance?${params.toString()}`);
        cachedAttendance = records;
        renderAttendanceTable();
    } catch (e) {
        console.error("Failed to load attendance records:", e);
        showToast("Failed to load attendance records", "danger");
        if (tbody) {
            tbody.innerHTML = `<tr><td colspan="10" class="text-center text-danger py-4"><i class="fa-solid fa-triangle-exclamation mr-2"></i> Failed to load attendance records: ${escapeHtml(e.message || 'Network or server error')} <br><button class="btn btn-sm btn-outline-secondary mt-2" onclick="loadAttendanceTab()"><i class="fa-solid fa-rotate-right"></i> Retry</button></td></tr>`;
        }
    }
}

function renderAttendanceTable() {
    const searchVal = (document.getElementById('attendanceSearch')?.value || '').toLowerCase().trim();
    const tbody = document.querySelector('#attendanceTable tbody');
    if (!tbody) return;

    const filtered = cachedAttendance.filter(r => {
        const text = `${r.student_name || ''} ${r.student_roll || ''} ${r.subject_code || ''} ${r.class_name || ''}`.toLowerCase();
        return text.includes(searchVal);
    });

    if (filtered.length === 0) {
        tbody.innerHTML = '<tr><td colspan="10" class="text-center text-muted py-4"><i class="fa-solid fa-inbox mr-2"></i> No attendance records yet.</td></tr>';
        return;
    }

    tbody.innerHTML = filtered.map(r => {
        let badgeClass = 'badge-secondary';
        if (r.status === 'PRESENT') badgeClass = 'badge-success';
        else if (r.status === 'ABSENT') badgeClass = 'badge-danger';
        else if (r.status === 'OD') badgeClass = 'badge-info';
        else if (r.status === 'UNCERTAIN') badgeClass = 'badge-warning';

        return `
            <tr>
                <td>${escapeHtml(r.session_date || '—')}</td>
                <td><strong>${escapeHtml(r.student_roll || '—')}</strong></td>
                <td>${escapeHtml(r.student_name || '—')}</td>
                <td>${escapeHtml(r.class_name || '—')}</td>
                <td><small>${escapeHtml(r.subject_code || '—')}</small></td>
                <td><span class="badge ${badgeClass}">${r.status}</span></td>
                <td><span class="badge badge-secondary small">${r.recognized_via || 'MANUAL'}</span></td>
                <td>${escapeHtml(r.od_reason || '—')}</td>
                <td><small class="text-muted">${escapeHtml(r.marked_by_name || 'System')}</small></td>
                <td>
                    <div class="btn-group gap-1">
                        <button class="btn btn-sm btn-outline-secondary" onclick="openEditAttendanceModal(${r.id})" title="Correct Attendance">
                            <i class="fa-solid fa-pen"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-danger" onclick="confirmDeleteAttendance(${r.id})" title="Delete Record">
                            <i class="fa-solid fa-trash"></i>
                        </button>
                    </div>
                </td>
            </tr>
        `;
    }).join('');
}

function openManualAttendanceModal() {
    const body = `
        <form id="manualAttendanceForm">
            <div class="alert alert-info">
                <i class="fa-solid fa-circle-info"></i>
                Manually record or override attendance for a student in a class session.
            </div>

            <div class="grid-2-col gap-3 mt-3">
                <div class="form-group">
                    <label>Session ID *</label>
                    <input type="number" id="manSessionId" class="form-control" required placeholder="e.g. 1" min="1">
                </div>
                <div class="form-group">
                    <label>Student ID *</label>
                    <input type="number" id="manStudentId" class="form-control" required placeholder="e.g. 1" min="1">
                </div>
            </div>

            <div class="grid-2-col gap-3 mt-2">
                <div class="form-group">
                    <label>Attendance Status *</label>
                    <select id="manStatus" class="form-control" required onchange="toggleManualOdReason(this.value)">
                        <option value="PRESENT">PRESENT</option>
                        <option value="ABSENT">ABSENT</option>
                        <option value="OD">ON DUTY (OD)</option>
                        <option value="UNCERTAIN">UNCERTAIN</option>
                    </select>
                </div>
                <div class="form-group" id="manOdReasonGroup" style="display: none;">
                    <label>OD Reason</label>
                    <input type="text" id="manOdReason" class="form-control" placeholder="e.g. Sports meet, Symposium">
                </div>
            </div>

            <div class="modal-actions mt-4">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="submit" class="btn btn-success"><i class="fa-solid fa-plus"></i> Save Attendance</button>
            </div>
        </form>
    `;
    openAdminModal("Record Manual Attendance", body);

    document.getElementById('manualAttendanceForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const payload = {
            session_id: parseInt(document.getElementById('manSessionId').value),
            student_id: parseInt(document.getElementById('manStudentId').value),
            status: document.getElementById('manStatus').value,
            od_reason: document.getElementById('manStatus').value === 'OD' ? document.getElementById('manOdReason').value.trim() : null
        };

        try {
            await apiFetch('/api/v1/admin/attendance/manual', {
                method: 'POST',
                body: JSON.stringify(payload)
            });
            showToast("Manual attendance recorded successfully", "success");
            closeAdminModal();
            loadAttendanceTab();
        } catch (err) {
            showToast(err.message || "Failed to record manual attendance", "danger");
        }
    });
}

function toggleManualOdReason(statusVal) {
    const group = document.getElementById('manOdReasonGroup');
    if (group) {
        group.style.display = statusVal === 'OD' ? 'block' : 'none';
    }
}

function openEditAttendanceModal(recordId) {
    const rec = cachedAttendance.find(r => r.id === recordId);
    if (!rec) return;

    const body = `
        <form id="editAttendanceForm">
            <div class="profile-card mb-3">
                <p><strong>Student:</strong> ${escapeHtml(rec.student_name)} (${escapeHtml(rec.student_roll)})</p>
                <p><strong>Session:</strong> #${rec.session_id} • ${escapeHtml(rec.subject_code || '')} - ${escapeHtml(rec.subject_name || '')} (${escapeHtml(rec.session_date || '')})</p>
                <p><strong>Current Status:</strong> <span class="badge badge-info">${rec.status}</span></p>
            </div>

            <div class="grid-2-col gap-3 mt-3">
                <div class="form-group">
                    <label>Corrected Status *</label>
                    <select id="editAttStatus" class="form-control" required onchange="toggleEditOdReason(this.value)">
                        <option value="PRESENT" ${rec.status === 'PRESENT' ? 'selected' : ''}>PRESENT</option>
                        <option value="ABSENT" ${rec.status === 'ABSENT' ? 'selected' : ''}>ABSENT</option>
                        <option value="OD" ${rec.status === 'OD' ? 'selected' : ''}>ON DUTY (OD)</option>
                        <option value="UNCERTAIN" ${rec.status === 'UNCERTAIN' ? 'selected' : ''}>UNCERTAIN</option>
                    </select>
                </div>
                <div class="form-group">
                    <label>Review Status</label>
                    <select id="editAttReview" class="form-control">
                        <option value="APPROVED" ${rec.review_status === 'APPROVED' ? 'selected' : ''}>APPROVED</option>
                        <option value="PENDING" ${rec.review_status === 'PENDING' ? 'selected' : ''}>PENDING</option>
                        <option value="REJECTED" ${rec.review_status === 'REJECTED' ? 'selected' : ''}>REJECTED</option>
                    </select>
                </div>
            </div>

            <div class="form-group mt-2" id="editOdReasonGroup" style="${rec.status === 'OD' ? 'display: block;' : 'display: none;'}">
                <label>OD Reason</label>
                <input type="text" id="editAttOdReason" class="form-control" value="${escapeHtml(rec.od_reason || '')}" placeholder="Reason for On Duty status">
            </div>

            <div class="modal-actions mt-4">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="submit" class="btn btn-primary"><i class="fa-solid fa-save"></i> Save Correction</button>
            </div>
        </form>
    `;
    openAdminModal(`Correct Attendance #${recordId}`, body);

    document.getElementById('editAttendanceForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const newStatus = document.getElementById('editAttStatus').value;
        const payload = {
            status: newStatus,
            review_status: document.getElementById('editAttReview').value,
            od_reason: newStatus === 'OD' ? document.getElementById('editAttOdReason').value.trim() : null
        };

        try {
            await apiFetch(`/api/v1/admin/attendance/${recordId}`, {
                method: 'PUT',
                body: JSON.stringify(payload)
            });
            showToast("Attendance corrected successfully", "success");
            closeAdminModal();
            loadAttendanceTab();
        } catch (err) {
            showToast(err.message || "Failed to correct attendance", "danger");
        }
    });
}

function toggleEditOdReason(statusVal) {
    const group = document.getElementById('editOdReasonGroup');
    if (group) {
        group.style.display = statusVal === 'OD' ? 'block' : 'none';
    }
}

async function confirmDeleteAttendance(recordId) {
    if (!confirm(`Are you sure you want to permanently delete attendance record #${recordId}?`)) return;
    try {
        await apiFetch(`/api/v1/admin/attendance/${recordId}`, { method: 'DELETE' });
        showToast("Attendance record deleted", "success");
        loadAttendanceTab();
    } catch (err) {
        showToast(err.message || "Failed to delete attendance record", "danger");
    }
}


// ====================================================
// TAB: CLASS SESSIONS MANAGEMENT
// ====================================================
async function loadSessionsTab() {
    const tbody = document.querySelector('#sessionsTable tbody');
    if (tbody) {
        tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted py-4"><i class="fa-solid fa-spinner fa-spin mr-2"></i> Loading class sessions...</td></tr>';
    }

    try {
        if (cachedClasses.length === 0) {
            cachedClasses = await apiFetch('/api/v1/admin/classes');
        }
        const clsFilter = document.getElementById('sessionClassFilter');
        if (clsFilter && clsFilter.children.length <= 1) {
            clsFilter.innerHTML = '<option value="">All Classes</option>' +
                cachedClasses.map(c => `<option value="${c.id}">${escapeHtml(c.name)}</option>`).join('');
        }

        const dateVal = document.getElementById('sessionDateFilter')?.value;
        const classVal = document.getElementById('sessionClassFilter')?.value;
        const statusVal = document.getElementById('sessionStatusFilter')?.value;

        const params = new URLSearchParams();
        if (dateVal) params.append('date', dateVal);
        if (classVal) params.append('class_id', classVal);
        if (statusVal) params.append('status', statusVal);

        const sessions = await apiFetch(`/api/v1/admin/sessions?${params.toString()}`);
        cachedSessions = sessions;
        renderSessionsTable();
    } catch (e) {
        console.error("Failed to load class sessions:", e);
        showToast("Failed to load class sessions", "danger");
        if (tbody) {
            tbody.innerHTML = `<tr><td colspan="8" class="text-center text-danger py-4"><i class="fa-solid fa-triangle-exclamation mr-2"></i> Failed to load class sessions: ${escapeHtml(e.message || 'Network or server error')} <br><button class="btn btn-sm btn-outline-secondary mt-2" onclick="loadSessionsTab()"><i class="fa-solid fa-rotate-right"></i> Retry</button></td></tr>`;
        }
    }
}

function renderSessionsTable() {
    const tbody = document.querySelector('#sessionsTable tbody');
    if (!tbody) return;

    if (cachedSessions.length === 0) {
        tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted py-4"><i class="fa-solid fa-inbox mr-2"></i> No class sessions yet.</td></tr>';
        return;
    }

    tbody.innerHTML = cachedSessions.map(s => {
        let badgeClass = 'badge-secondary';
        if (s.status === 'ACTIVE') badgeClass = 'badge-success';
        else if (s.status === 'SCHEDULED') badgeClass = 'badge-info';
        else if (s.status === 'CANCELLED') badgeClass = 'badge-danger';

        return `
            <tr>
                <td><strong>#${s.id}</strong></td>
                <td>${escapeHtml(s.date || '—')}</td>
                <td>${escapeHtml(s.class_name || '—')}</td>
                <td><strong>${escapeHtml(s.subject_code || '—')}</strong> <small class="text-muted">${escapeHtml(s.subject_name || '')}</small></td>
                <td>${escapeHtml(s.faculty_name || '—')}</td>
                <td><span class="badge ${badgeClass}">${s.status}</span></td>
                <td><span class="badge badge-info">${s.attendance_count ?? 0} Records</span></td>
                <td>
                    <div class="btn-group gap-1">
                        <button class="btn btn-sm btn-outline-info" onclick="viewSessionRoster(${s.id})" title="Inspect Roster">
                            <i class="fa-solid fa-list-check"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-secondary" onclick="openEditSessionModal(${s.id})" title="Edit Session">
                            <i class="fa-solid fa-pen"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-danger" onclick="confirmDeleteSession(${s.id}, ${s.attendance_count ?? 0})" title="Delete Session">
                            <i class="fa-solid fa-trash"></i>
                        </button>
                    </div>
                </td>
            </tr>
        `;
    }).join('');
}

function openCreateSessionModal() {
    const today = new Date().toISOString().split('T')[0];
    const facOpts = cachedFaculty.map(f => `<option value="${f.id}">${escapeHtml(f.full_name)} (${escapeHtml(f.employee_id)})</option>`).join('');

    const body = `
        <form id="createSessionForm">
            <div class="grid-2-col gap-3">
                <div class="form-group">
                    <label>Session Date *</label>
                    <input type="date" id="newSessDate" class="form-control" required value="${today}">
                </div>
                <div class="form-group">
                    <label>Faculty Member *</label>
                    <select id="newSessFaculty" class="form-control" required>
                        <option value="">Select Faculty</option>
                        ${facOpts}
                    </select>
                </div>
            </div>

            <div class="grid-2-col gap-3 mt-2">
                <div class="form-group">
                    <label>Timetable Entry ID (Optional)</label>
                    <input type="number" id="newSessTimetableId" class="form-control" placeholder="e.g. 1" min="1">
                </div>
                <div class="form-group">
                    <label>Initial Status</label>
                    <select id="newSessStatus" class="form-control">
                        <option value="SCHEDULED">SCHEDULED</option>
                        <option value="ACTIVE">ACTIVE</option>
                    </select>
                </div>
            </div>

            <div class="modal-actions mt-4">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="submit" class="btn btn-success"><i class="fa-solid fa-plus"></i> Create Session</button>
            </div>
        </form>
    `;
    openAdminModal("Create Class Session", body);

    document.getElementById('createSessionForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const ttId = document.getElementById('newSessTimetableId').value;
        const payload = {
            date: document.getElementById('newSessDate').value,
            faculty_id: parseInt(document.getElementById('newSessFaculty').value),
            timetable_entry_id: ttId ? parseInt(ttId) : null,
            status: document.getElementById('newSessStatus').value
        };

        try {
            await apiFetch('/api/v1/admin/sessions', {
                method: 'POST',
                body: JSON.stringify(payload)
            });
            showToast("Session created successfully", "success");
            closeAdminModal();
            loadSessionsTab();
        } catch (err) {
            showToast(err.message || "Failed to create session", "danger");
        }
    });
}

function openEditSessionModal(sessionId) {
    const sess = cachedSessions.find(s => s.id === sessionId);
    if (!sess) return;

    const facOpts = cachedFaculty.map(f => `<option value="${f.id}" ${f.id === sess.faculty_id ? 'selected' : ''}>${escapeHtml(f.full_name)} (${escapeHtml(f.employee_id)})</option>`).join('');

    const body = `
        <form id="editSessionForm">
            <div class="grid-2-col gap-3">
                <div class="form-group">
                    <label>Session Date</label>
                    <input type="date" id="editSessDate" class="form-control" value="${sess.date}">
                </div>
                <div class="form-group">
                    <label>Faculty Member</label>
                    <select id="editSessFaculty" class="form-control">
                        ${facOpts}
                    </select>
                </div>
            </div>

            <div class="form-group mt-2">
                <label>Session Status</label>
                <select id="editSessStatus" class="form-control">
                    <option value="SCHEDULED" ${sess.status === 'SCHEDULED' ? 'selected' : ''}>SCHEDULED</option>
                    <option value="ACTIVE" ${sess.status === 'ACTIVE' ? 'selected' : ''}>ACTIVE</option>
                    <option value="COMPLETED" ${sess.status === 'COMPLETED' ? 'selected' : ''}>COMPLETED</option>
                    <option value="CANCELLED" ${sess.status === 'CANCELLED' ? 'selected' : ''}>CANCELLED</option>
                </select>
            </div>

            <div class="modal-actions mt-4">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="submit" class="btn btn-primary"><i class="fa-solid fa-save"></i> Save Changes</button>
            </div>
        </form>
    `;
    openAdminModal(`Edit Session #${sessionId}`, body);

    document.getElementById('editSessionForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const payload = {
            date: document.getElementById('editSessDate').value || undefined,
            faculty_id: parseInt(document.getElementById('editSessFaculty').value),
            status: document.getElementById('editSessStatus').value
        };

        try {
            await apiFetch(`/api/v1/admin/sessions/${sessionId}`, {
                method: 'PUT',
                body: JSON.stringify(payload)
            });
            showToast("Session updated successfully", "success");
            closeAdminModal();
            loadSessionsTab();
        } catch (err) {
            showToast(err.message || "Failed to update session", "danger");
        }
    });
}

function confirmDeleteSession(sessionId, recordCount) {
    let warningText = `Are you sure you want to delete session #${sessionId}?`;
    let cascadeOption = '';

    if (recordCount > 0) {
        warningText = `This session contains <strong>${recordCount}</strong> attendance record(s).`;
        cascadeOption = `
            <div class="form-check mt-3 alert alert-danger">
                <label class="d-flex align-center gap-2">
                    <input type="checkbox" id="cascadeDeleteCheck">
                    <span><strong>Confirm Cascading Deletion:</strong> Permanently delete this session and all ${recordCount} associated attendance records.</span>
                </label>
            </div>
        `;
    }

    const body = `
        <p>${warningText}</p>
        ${cascadeOption}
        <div class="modal-actions mt-4">
            <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
            <button type="button" class="btn btn-danger" onclick="executeDeleteSession(${sessionId}, ${recordCount > 0})">
                <i class="fa-solid fa-trash"></i> Delete Session
            </button>
        </div>
    `;
    openAdminModal(`Delete Session #${sessionId}`, body);
}

async function executeDeleteSession(sessionId, requiresCascade) {
    let cascade = false;
    if (requiresCascade) {
        const chk = document.getElementById('cascadeDeleteCheck');
        if (!chk || !chk.checked) {
            showToast("Please check the confirmation box to delete the session and its records", "warning");
            return;
        }
        cascade = true;
    }

    try {
        await apiFetch(`/api/v1/admin/sessions/${sessionId}?cascade=${cascade}`, { method: 'DELETE' });
        showToast("Session deleted successfully", "success");
        closeAdminModal();
        loadSessionsTab();
    } catch (err) {
        showToast(err.message || "Failed to delete session", "danger");
    }
}

async function viewSessionRoster(sessionId) {
    try {
        const details = await apiFetch(`/api/v1/admin/sessions/${sessionId}`);
        const roster = details.roster || details.students || [];
        const summary = details.summary || {};
        const totalStudents = summary.total_students ?? details.total_students ?? roster.length;
        const presentCount = summary.present_count ?? details.present_count ?? 0;
        const absentCount = summary.absent_count ?? details.absent_count ?? 0;
        const odCount = summary.od_count ?? details.od_count ?? 0;

        const rows = roster.map(st => {
            const stStatus = st.attendance_status || st.status || 'UNMARKED';
            const stName = st.full_name || st.student_name || '—';
            let badgeClass = 'badge-secondary';
            if (stStatus === 'PRESENT') badgeClass = 'badge-success';
            else if (stStatus === 'ABSENT') badgeClass = 'badge-danger';
            else if (stStatus === 'OD') badgeClass = 'badge-info';
            else if (stStatus === 'UNCERTAIN') badgeClass = 'badge-warning';

            return `
                <tr>
                    <td><strong>${escapeHtml(st.roll_number || '—')}</strong></td>
                    <td>${escapeHtml(stName)}</td>
                    <td><span class="badge ${badgeClass}">${stStatus}</span></td>
                    <td>${st.confidence ? `${st.confidence.toFixed(1)}%` : '—'}</td>
                    <td><small class="text-muted">${st.recognized_via || '—'}</small></td>
                    <td><small class="text-muted">${st.marked_at ? formatDate(st.marked_at) : '—'}</small></td>
                </tr>
            `;
        }).join('') || '<tr><td colspan="6" class="text-center text-muted">No students in session roster.</td></tr>';

        const body = `
            <div class="profile-card mb-3">
                <div class="grid-2-col gap-2">
                    <div>
                        <p><strong>Session ID:</strong> #${details.session_id || details.id}</p>
                        <p><strong>Subject:</strong> ${escapeHtml(details.subject_name || '')} (${escapeHtml(details.subject_code || '')})</p>
                        <p><strong>Class Section:</strong> ${escapeHtml(details.class_name || '')}</p>
                    </div>
                    <div>
                        <p><strong>Faculty:</strong> ${escapeHtml(details.faculty_name || '')}</p>
                        <p><strong>Date:</strong> ${details.date}</p>
                        <p><strong>Status:</strong> <span class="badge badge-info">${details.status}</span></p>
                    </div>
                </div>
            </div>
            <div class="metrics-grid mb-3">
                <div class="metric-card" style="padding: 10px;">
                    <span class="small text-muted">Total Enrolled</span>
                    <h4>${totalStudents}</h4>
                </div>
                <div class="metric-card" style="padding: 10px;">
                    <span class="small text-muted">Present</span>
                    <h4 class="text-success">${presentCount}</h4>
                </div>
                <div class="metric-card" style="padding: 10px;">
                    <span class="small text-muted">Absent</span>
                    <h4 class="text-danger">${absentCount}</h4>
                </div>
                <div class="metric-card" style="padding: 10px;">
                    <span class="small text-muted">On Duty</span>
                    <h4 class="text-info">${odCount}</h4>
                </div>
            </div>
            <div class="table-responsive" style="max-height: 350px; overflow-y: auto;">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Roll Number</th>
                            <th>Student Name</th>
                            <th>Status</th>
                            <th>Confidence</th>
                            <th>Source</th>
                            <th>Marked At</th>
                        </tr>
                    </thead>
                    <tbody>${rows}</tbody>
                </table>
            </div>
            <div class="modal-actions mt-4">
                <button type="button" class="btn btn-secondary btn-block" onclick="closeAdminModal()">Close</button>
            </div>
        `;
        openAdminModal(`Session #${sessionId} — Roster Inspection`, body);
    } catch (err) {
        showToast(err.message || "Failed to load session roster", "danger");
    }
}


// ====================================================
// TAB: BIOMETRIC FACE PROFILES & RECOGNITION CONTROL
// ====================================================
async function loadBiometricsTab() {
    try {
        if (cachedClasses.length === 0) {
            cachedClasses = await apiFetch('/api/v1/admin/classes');
        }
        const clsFilter = document.getElementById('bioClassFilter');
        if (clsFilter && clsFilter.children.length <= 1) {
            clsFilter.innerHTML = '<option value="">All Classes</option>' +
                cachedClasses.map(c => `<option value="${c.id}">${escapeHtml(c.name)}</option>`).join('');
        }

        const [summary, students] = await Promise.all([
            apiFetch('/api/v1/admin/biometrics/summary'),
            (async () => {
                const searchVal = document.getElementById('bioSearch')?.value || '';
                const statusVal = document.getElementById('bioStatusFilter')?.value;
                const classVal = document.getElementById('bioClassFilter')?.value;

                const params = new URLSearchParams();
                if (searchVal) params.append('search', searchVal);
                if (statusVal !== "" && statusVal !== undefined) params.append('enrolled_only', statusVal);
                if (classVal) params.append('class_id', classVal);

                return await apiFetch(`/api/v1/admin/biometrics/students?${params.toString()}`);
            })()
        ]);

        if (document.getElementById('bioEngineName')) {
            document.getElementById('bioEngineName').innerText = `${summary.model_name} ${summary.model_version}`;
        }
        if (document.getElementById('bioDimension')) {
            document.getElementById('bioDimension').innerText = `${summary.dimension}D (${summary.distance_metric})`;
        }
        if (document.getElementById('bioEnrolledCount')) {
            document.getElementById('bioEnrolledCount').innerText = summary.enrolled_count ?? 0;
        }
        if (document.getElementById('bioPendingCount')) {
            document.getElementById('bioPendingCount').innerText = summary.pending_count ?? 0;
        }

        cachedBiometrics = students;
        renderBiometricsTable();
    } catch (e) {
        showToast("Failed to load biometric data", "danger");
    }
}

function renderBiometricsTable() {
    const searchVal = (document.getElementById('bioSearch')?.value || '').toLowerCase().trim();
    const tbody = document.querySelector('#biometricsTable tbody');
    if (!tbody) return;

    const filtered = cachedBiometrics.filter(b => {
        const text = `${b.full_name || ''} ${b.roll_number || ''} ${b.class_name || ''}`.toLowerCase();
        return text.includes(searchVal);
    });

    if (filtered.length === 0) {
        tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted">No biometric records match the filter.</td></tr>';
        return;
    }

    tbody.innerHTML = filtered.map(b => {
        const isEnrolled = b.enrolled || b.template_count >= 1;
        const statusBadge = isEnrolled
            ? '<span class="badge badge-success"><i class="fa-solid fa-check"></i> Enrolled</span>'
            : `<span class="badge badge-warning"><i class="fa-solid fa-clock"></i> Not Enrolled</span>`;

        const datasetBtn = `<button class="btn btn-sm btn-outline-info" onclick="openStudentDatasetModal(${b.student_id}, '${escapeHtml(b.full_name)}', '${escapeHtml(b.roll_number)}')" title="View Face Dataset & Photos">
            <i class="fa-solid fa-images"></i> Dataset
        </button>`;

        const enrollBtn = isEnrolled
            ? `<button class="btn btn-sm btn-outline-warning" onclick="openAdminEnrollModal(${b.student_id}, '${escapeHtml(b.full_name)}', '${escapeHtml(b.roll_number)}', true)" title="Replace Face Enrollment">
                   <i class="fa-solid fa-arrows-rotate"></i> Replace
               </button>`
            : `<button class="btn btn-sm btn-success" onclick="openAdminEnrollModal(${b.student_id}, '${escapeHtml(b.full_name)}', '${escapeHtml(b.roll_number)}', false)" title="Add Face Enrollment">
                   <i class="fa-solid fa-camera"></i> Add Face
               </button>`;

        const addPhotosBtn = `<button class="btn btn-sm btn-outline-primary" onclick="openAdminMultiEnrollModal(${b.student_id}, '${escapeHtml(b.full_name)}', '${escapeHtml(b.roll_number)}', false)" title="Upload Multiple Face Photos">
            <i class="fa-solid fa-cloud-arrow-up"></i> Upload
        </button>`;

        const resetBtn = b.template_count > 0
            ? `<button class="btn btn-sm btn-outline-danger" onclick="confirmResetBiometrics(${b.student_id}, '${escapeHtml(b.full_name)}', ${b.template_count})" title="Revoke & Reset Templates">
                   <i class="fa-solid fa-trash-arrow-up"></i>
               </button>`
            : '';

        return `
            <tr>
                <td><strong>${escapeHtml(b.roll_number)}</strong></td>
                <td>${escapeHtml(b.full_name)}</td>
                <td>${escapeHtml(b.class_name || '—')}</td>
                <td>${statusBadge}</td>
                <td><span class="badge badge-primary">${b.template_count} template(s)</span></td>
                <td><small class="text-muted">${escapeHtml(b.model_name)} / ${escapeHtml(b.detector_name)}</small></td>
                <td><small class="text-muted">${b.last_enrollment_at ? formatDate(b.last_enrollment_at) : 'Never'}</small></td>
                <td>
                    <div class="btn-group gap-1">
                        ${datasetBtn}
                        ${enrollBtn}
                        ${addPhotosBtn}
                        ${resetBtn}
                    </div>
                </td>
            </tr>
        `;
    }).join('');
}

function openAdminEnrollModal(studentId, fullName, rollNumber, isReplace) {
    const title = isReplace ? `Replace Face — ${fullName}` : `Add Face — ${fullName}`;
    const btnLabel = isReplace ? 'Confirm Replace' : 'Confirm Enrollment';
    const warningMsg = isReplace
        ? '<div class="alert alert-warning"><i class="fa-solid fa-triangle-exclamation"></i> <strong>Note:</strong> Replacing face will delete the student\'s existing biometric templates.</div>'
        : '';

    const body = `
        <div class="enroll-modal-content">
            <div class="card p-3 mb-3 bg-dark-subtle border">
                <strong>Student:</strong> ${escapeHtml(fullName)}<br>
                <strong>Roll Number:</strong> ${escapeHtml(rollNumber)}
            </div>
            ${warningMsg}
            <div class="form-group mb-3">
                <label><strong>Select Student Photo (JPEG/PNG):</strong></label>
                <input type="file" id="adminEnrollFileInput" class="form-control" accept="image/jpeg,image/png,image/webp" onchange="previewAdminEnrollImage(event)">
            </div>
            <div id="adminEnrollPreviewContainer" class="text-center mb-3" style="display: none;">
                <img id="adminEnrollPreviewImg" src="" alt="Face Preview" style="max-width: 220px; max-height: 220px; border-radius: 8px; border: 2px solid var(--accent, #c5a059); object-fit: cover;">
                <div class="text-success small mt-1"><i class="fa-solid fa-circle-check"></i> Image selected for enrollment</div>
            </div>
            <div id="adminEnrollError" class="alert alert-danger" style="display: none;"></div>
            <div class="modal-actions mt-3">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="button" id="adminEnrollSubmitBtn" class="btn ${isReplace ? 'btn-warning' : 'btn-success'}" onclick="executeAdminEnroll(${studentId}, ${isReplace})">
                    <i class="fa-solid fa-upload"></i> ${btnLabel}
                </button>
            </div>
        </div>
    `;
    openAdminModal(title, body);
}

function previewAdminEnrollImage(event) {
    const file = event.target.files && event.target.files[0];
    const previewContainer = document.getElementById('adminEnrollPreviewContainer');
    const previewImg = document.getElementById('adminEnrollPreviewImg');
    const errBox = document.getElementById('adminEnrollError');
    if (errBox) errBox.style.display = 'none';

    if (file) {
        const reader = new FileReader();
        reader.onload = function(e) {
            if (previewImg) previewImg.src = e.target.result;
            if (previewContainer) previewContainer.style.display = 'block';
        };
        reader.readAsDataURL(file);
    } else {
        if (previewContainer) previewContainer.style.display = 'none';
    }
}

async function executeAdminEnroll(studentId, isReplace) {
    const fileInput = document.getElementById('adminEnrollFileInput');
    const errBox = document.getElementById('adminEnrollError');
    const submitBtn = document.getElementById('adminEnrollSubmitBtn');

    if (!fileInput || !fileInput.files || fileInput.files.length === 0) {
        if (errBox) {
            errBox.innerText = 'Please select a photo file to enroll.';
            errBox.style.display = 'block';
        }
        return;
    }

    const file = fileInput.files[0];
    const formData = new FormData();
    formData.append('file', file);

    if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Processing...';
    }
    if (errBox) errBox.style.display = 'none';

    try {
        const token = localStorage.getItem('access_token');
        const url = `/api/v1/admin/students/${studentId}/enroll-face?replace=${isReplace}`;
        const response = await fetch(url, {
            method: 'POST',
            headers: token ? { 'Authorization': `Bearer ${token}` } : {},
            body: formData
        });

        const data = await response.json();
        if (!response.ok) {
            throw new Error(data.detail || data.message || 'Enrollment failed');
        }

        showToast(data.message || 'Face enrolled successfully', 'success');
        closeAdminModal();
        loadBiometricsTab();
    } catch (err) {
        if (errBox) {
            errBox.innerText = err.message || 'Face enrollment failed. Ensure a single clear face is visible.';
            errBox.style.display = 'block';
        }
        if (submitBtn) {
            submitBtn.disabled = false;
            submitBtn.innerHTML = isReplace ? '<i class="fa-solid fa-upload"></i> Confirm Replace' : '<i class="fa-solid fa-upload"></i> Confirm Enrollment';
        }
    }
}

function confirmResetBiometrics(studentId, fullName, templateCount) {
    const body = `
        <div class="alert alert-danger">
            <i class="fa-solid fa-triangle-exclamation"></i>
            <strong>Revoke Biometrics Warning:</strong>
            Are you sure you want to revoke and delete all <strong>${templateCount}</strong> facial recognition template(s) for <strong>${escapeHtml(fullName)}</strong>?
        </div>
        <p class="text-muted small mt-2">The student will be returned to <em>Pending Enrollment</em> status and must re-enroll their face on a mobile device or at the administrative terminal before live camera attendance will recognize them.</p>
        <div class="modal-actions mt-4">
            <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
            <button type="button" class="btn btn-danger" onclick="executeResetBiometrics(${studentId})">
                <i class="fa-solid fa-trash-arrow-up"></i> Revoke & Reset
            </button>
        </div>
    `;
    openAdminModal(`Reset Biometrics — ${fullName}`, body);
}

async function executeResetBiometrics(studentId) {
    try {
        const res = await apiFetch(`/api/v1/admin/biometrics/${studentId}/reset`, { method: 'POST' });
        showToast(res.message || "Biometric templates deleted successfully", "success");
        closeAdminModal();
        loadBiometricsTab();
    } catch (err) {
        showToast(err.message || "Failed to reset biometrics", "danger");
    }
}

// ====================================================
// PHASE 7.8: CANONICAL STUDENT DATASET VIEWER & MULTI-PHOTO ENROLLMENT
// ====================================================

async function openStudentDatasetModal(studentId, fullName, rollNumber) {
    const title = `<i class="fa-solid fa-images text-info mr-2"></i> Face Dataset — ${escapeHtml(fullName)}`;
    const loadingBody = `
        <div class="text-center p-4">
            <i class="fa-solid fa-spinner fa-spin fa-2x text-primary mb-3"></i>
            <div>Loading student dataset photos...</div>
        </div>
    `;
    openAdminModal(title, loadingBody);

    try {
        const dataset = await apiFetch(`/api/v1/admin/students/${studentId}/photos`);
        renderStudentDatasetModal(studentId, fullName, rollNumber, dataset);
    } catch (err) {
        document.getElementById('modalBody').innerHTML = `
            <div class="alert alert-danger">
                <i class="fa-solid fa-circle-exclamation mr-1"></i> Failed to load dataset: ${escapeHtml(err.message)}
            </div>
            <div class="modal-actions">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Close</button>
            </div>
        `;
    }
}

function renderStudentDatasetModal(studentId, fullName, rollNumber, dataset) {
    const photos = dataset.photos || [];
    const photoCount = dataset.photo_count || photos.length;
    const templateCount = dataset.template_count || 0;

    let galleryHtml = '';
    if (photos.length === 0) {
        galleryHtml = `
            <div class="text-center p-4 text-muted border rounded" style="background: rgba(15, 23, 42, 0.4);">
                <i class="fa-solid fa-camera fa-2x mb-2 text-secondary"></i>
                <div class="font-bold">No Face Photos Stored</div>
                <div class="small">No photos found in <code>data/student_faces/${escapeHtml(rollNumber)}/</code>.</div>
            </div>
        `;
    } else {
        galleryHtml = `
            <div class="row g-3" style="max-height: 380px; overflow-y: auto; padding-right: 4px;">
                ${photos.map(p => `
                    <div class="col-6 col-md-4" id="photoCard-${p.embedding_id}">
                        <div class="card h-100 border p-2" style="background: rgba(15, 23, 42, 0.6); border-radius: 8px;">
                            <div class="position-relative" style="height: 120px; overflow: hidden; border-radius: 6px; background: #0b1120;">
                                <img src="/api/v1/admin/students/${studentId}/photos/${p.embedding_id}/image" 
                                     alt="${escapeHtml(p.filename)}"
                                     class="w-100 h-100" 
                                     style="object-fit: cover;"
                                     onerror="this.onerror=null; this.src='data:image/svg+xml;utf8,<svg xmlns=\\'http://www.w3.org/2000/svg\\' width=\\'100\\' height=\\'100\\'><rect width=\\'100\\' height=\\'100\\' fill=\\'%23334155\\'/><text x=\\'50%\\' y=\\'50%\\' fill=\\'%2394a3b8\\' font-size=\\'12\\' text-anchor=\\'middle\\' dy=\\'.3em\\'>No Image</text></svg>';">
                                <button type="button" class="btn btn-sm btn-danger position-absolute top-0 end-0 m-1" 
                                        style="padding: 2px 6px; border-radius: 50%; opacity: 0.85;"
                                        title="Delete photo"
                                        onclick="confirmDeleteStudentPhoto(${studentId}, ${p.embedding_id}, '${escapeHtml(p.filename)}', '${escapeHtml(fullName)}', '${escapeHtml(rollNumber)}')">
                                    <i class="fa-solid fa-trash-can" style="font-size: 10px;"></i>
                                </button>
                            </div>
                            <div class="mt-2 small">
                                <div class="font-bold text-truncate" title="${escapeHtml(p.filename)}">${escapeHtml(p.filename)}</div>
                                <div class="text-muted d-flex justify-content-between" style="font-size: 10px;">
                                    <span>${p.created_at ? p.created_at.split('T')[0] : 'ID: ' + p.embedding_id}</span>
                                    ${p.quality_score ? `<span class="text-success font-bold">Q: ${(p.quality_score * 100).toFixed(0)}%</span>` : ''}
                                </div>
                            </div>
                        </div>
                    </div>
                `).join('')}
            </div>
        `;
    }

    const body = `
        <div class="student-dataset-view">
            <div class="p-3 mb-3 border rounded" style="background: rgba(15, 23, 42, 0.7); border-color: rgba(59, 130, 246, 0.3) !important;">
                <div class="d-flex justify-content-between align-items-center flex-wrap gap-2">
                    <div>
                        <h6 class="mb-0 font-bold text-white">${escapeHtml(fullName)} (${escapeHtml(rollNumber)})</h6>
                        <small class="text-muted"><code>data/student_faces/${escapeHtml(rollNumber)}/</code></small>
                    </div>
                    <div class="d-flex gap-2">
                        <span class="badge badge-primary">${photoCount} Photos</span>
                        <span class="badge badge-success">${templateCount} Active Templates</span>
                    </div>
                </div>
            </div>

            <div class="d-flex justify-content-between align-items-center mb-3">
                <h6 class="mb-0 font-bold"><i class="fa-solid fa-photo-film mr-1 text-primary"></i> Photo Gallery</h6>
                <div class="d-flex gap-2">
                    <button type="button" class="btn btn-sm btn-primary" onclick="openAdminMultiEnrollModal(${studentId}, '${escapeHtml(fullName)}', '${escapeHtml(rollNumber)}', false)">
                        <i class="fa-solid fa-plus mr-1"></i> Add Photos
                    </button>
                    <button type="button" class="btn btn-sm btn-outline-warning" onclick="openAdminMultiEnrollModal(${studentId}, '${escapeHtml(fullName)}', '${escapeHtml(rollNumber)}', true)">
                        <i class="fa-solid fa-arrows-rotate mr-1"></i> Replace All
                    </button>
                </div>
            </div>

            ${galleryHtml}

            <div class="modal-actions mt-3">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Close</button>
            </div>
        </div>
    `;

    document.getElementById('modalBody').innerHTML = body;
}

async function confirmDeleteStudentPhoto(studentId, embeddingId, filename, fullName, rollNumber) {
    if (!confirm(`Are you sure you want to delete "${filename}"?\n\nThis will remove the file from data/student_faces/ and delete its biometric template.`)) {
        return;
    }

    try {
        const res = await apiFetch(`/api/v1/admin/students/${studentId}/photos/${embeddingId}`, { method: 'DELETE' });
        showToast(res.message || "Photo deleted successfully", "success");
        // Reload dataset modal
        const dataset = await apiFetch(`/api/v1/admin/students/${studentId}/photos`);
        renderStudentDatasetModal(studentId, fullName, rollNumber, dataset);
        loadBiometricsTab();
    } catch (err) {
        showToast(err.message || "Failed to delete photo", "danger");
    }
}

function openAdminMultiEnrollModal(studentId, fullName, rollNumber, isReplace = false) {
    const title = isReplace 
        ? `<i class="fa-solid fa-arrows-rotate text-warning mr-2"></i> Replace Face Dataset — ${escapeHtml(fullName)}`
        : `<i class="fa-solid fa-cloud-arrow-up text-primary mr-2"></i> Add Face Photos — ${escapeHtml(fullName)}`;

    const warningHtml = isReplace
        ? `<div class="alert alert-warning py-2 small mb-3">
               <i class="fa-solid fa-triangle-exclamation mr-1"></i> 
               <strong>Warning:</strong> Replacing will delete ALL previous photos in <code>data/student_faces/${escapeHtml(rollNumber)}/</code> and regenerate templates from the new uploads.
           </div>`
        : '';

    const body = `
        <div class="multi-enroll-modal">
            <div class="p-2 mb-3 border rounded bg-dark-subtle small">
                <strong>Student:</strong> ${escapeHtml(fullName)} | <strong>Register No:</strong> ${escapeHtml(rollNumber)}
            </div>
            ${warningHtml}
            <div class="form-group mb-3">
                <label class="form-label font-bold small">Select 1 or More Face Photos (JPEG, PNG):</label>
                <input type="file" id="multiEnrollFilesInput" class="form-control" multiple accept="image/jpeg,image/png,image/webp">
                <small class="text-muted">You can select multiple photos at once. Each photo will be inspected for a single face.</small>
            </div>
            <div id="multiEnrollStatus" class="small mb-3" style="display: none;"></div>
            <div class="modal-actions">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="button" id="btnSubmitMultiEnroll" class="btn ${isReplace ? 'btn-warning' : 'btn-primary'}" onclick="executeAdminMultiEnroll(${studentId}, '${escapeHtml(fullName)}', '${escapeHtml(rollNumber)}', ${isReplace})">
                    <i class="fa-solid fa-upload mr-1"></i> ${isReplace ? 'Replace Dataset' : 'Upload & Enroll'}
                </button>
            </div>
        </div>
    `;

    openAdminModal(title, body);
}

async function executeAdminMultiEnroll(studentId, fullName, rollNumber, isReplace) {
    const fileInput = document.getElementById('multiEnrollFilesInput');
    const statusBox = document.getElementById('multiEnrollStatus');
    const submitBtn = document.getElementById('btnSubmitMultiEnroll');

    if (!fileInput || !fileInput.files || fileInput.files.length === 0) {
        if (statusBox) {
            statusBox.className = 'alert alert-warning py-2 small mb-3';
            statusBox.style.display = 'block';
            statusBox.innerText = 'Please select at least one photo file.';
        }
        return;
    }

    const formData = new FormData();
    for (let i = 0; i < fileInput.files.length; i++) {
        formData.append('files', fileInput.files[i]);
    }
    formData.append('replace', isReplace.toString());

    if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin mr-1"></i> Processing embeddings...';
    }
    if (statusBox) {
        statusBox.className = 'alert alert-info py-2 small mb-3';
        statusBox.style.display = 'block';
        statusBox.innerHTML = '<i class="fa-solid fa-gear fa-spin mr-1"></i> Running face detection, quality analysis & saving to canonical dataset...';
    }

    try {
        const token = localStorage.getItem('access_token');
        const url = `/api/v1/admin/students/${studentId}/enroll-photos?replace=${isReplace}`;
        const res = await fetch(url, {
            method: 'POST',
            headers: token ? { 'Authorization': `Bearer ${token}` } : {},
            body: formData,
            credentials: 'include'
        });

        const data = await res.json();
        if (!res.ok) {
            throw new Error(data.detail || data.message || 'Enrollment failed');
        }

        renderMultiEnrollResult(studentId, fullName, rollNumber, data);
        loadBiometricsTab();
    } catch (err) {
        if (statusBox) {
            statusBox.className = 'alert alert-danger py-2 small mb-3';
            statusBox.style.display = 'block';
            statusBox.innerText = err.message || 'Multi-photo enrollment failed.';
        }
        if (submitBtn) {
            submitBtn.disabled = false;
            submitBtn.innerHTML = isReplace ? '<i class="fa-solid fa-upload mr-1"></i> Replace Dataset' : '<i class="fa-solid fa-upload mr-1"></i> Upload & Enroll';
        }
    }
}

function renderMultiEnrollResult(studentId, fullName, rollNumber, result) {
    const items = result.items || [];
    const validCount = result.valid_enrolled || 0;
    const rejCount = result.rejected || 0;
    const total = result.total_files || items.length;

    const body = `
        <div class="multi-enroll-result">
            <div class="alert alert-${validCount > 0 ? 'success' : 'warning'} py-2 mb-3">
                <div class="d-flex align-items-center gap-2">
                    <i class="fa-solid fa-${validCount > 0 ? 'circle-check' : 'circle-exclamation'} fa-lg"></i>
                    <div>
                        <strong>${escapeHtml(result.message || 'Enrollment Finished')}</strong>
                        <div class="small">${validCount} of ${total} photos enrolled (${rejCount} rejected/skipped).</div>
                    </div>
                </div>
            </div>

            <div class="table-responsive" style="max-height: 260px; overflow-y: auto;">
                <table class="table table-sm table-bordered">
                    <thead>
                        <tr>
                            <th>File</th>
                            <th>Status</th>
                            <th>Faces</th>
                            <th>Detail</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${items.map(it => {
                            const isOk = it.status === 'ENROLLED';
                            const badgeClass = isOk ? 'badge-success' : (it.status.includes('DUPLICATE') ? 'badge-warning' : 'badge-danger');
                            return `
                                <tr>
                                    <td><small class="font-bold">${escapeHtml(it.filename)}</small></td>
                                    <td><span class="badge ${badgeClass}">${escapeHtml(it.status)}</span></td>
                                    <td><small>${it.faces_detected}</small></td>
                                    <td><small class="text-muted">${escapeHtml(it.reason || '')}</small></td>
                                </tr>
                            `;
                        }).join('')}
                    </tbody>
                </table>
            </div>

            <div class="modal-actions mt-3 d-flex justify-content-between">
                <button type="button" class="btn btn-outline-info" onclick="openStudentDatasetModal(${studentId}, '${escapeHtml(fullName)}', '${escapeHtml(rollNumber)}')">
                    <i class="fa-solid fa-images mr-1"></i> View Dataset Gallery
                </button>
                <button type="button" class="btn btn-primary" onclick="closeAdminModal()">Done</button>
            </div>
        </div>
    `;

    document.getElementById('modalBody').innerHTML = body;
}


// ====================================================
// FOLDER-BASED STUDENT FACE ENROLLMENT (PHASE 7.7)
// ====================================================

let selectedFolderFiles = [];

function openAdminFolderEnrollModal() {
    selectedFolderFiles = [];
    const body = `
        <div class="folder-enroll-wrapper">
            <div class="alert alert-info py-2 px-3 mb-3 small" style="background: rgba(59, 130, 246, 0.1); border: 1px solid rgba(59, 130, 246, 0.25); border-radius: 8px;">
                <div class="d-flex align-items-center gap-2">
                    <i class="fa-solid fa-circle-info text-primary"></i>
                    <div>
                        <strong>Folder Name = Student Identity:</strong> The folder name MUST be the student's Register Number (e.g., <code>721025149001</code>). Image filenames are completely irrelevant to student identity.
                    </div>
                </div>
            </div>

            <!-- Tab Buttons -->
            <div class="d-flex gap-2 mb-3 border-bottom pb-2">
                <button type="button" id="tabBtnHostPath" class="btn btn-sm btn-primary" onclick="switchFolderEnrollMode('host')">
                    <i class="fa-solid fa-server mr-1"></i> Host / Server Directory
                </button>
                <button type="button" id="tabBtnBrowserUpload" class="btn btn-sm btn-secondary" onclick="switchFolderEnrollMode('browser')">
                    <i class="fa-solid fa-folder-open mr-1"></i> Browser Folder Upload
                </button>
            </div>

            <!-- Host Path Mode -->
            <div id="modeHostPath" class="folder-enroll-mode">
                <div class="form-group mb-3">
                    <label class="form-label font-bold small mb-1">Local Server Dataset Path *</label>
                    <div class="input-group d-flex gap-2">
                        <input type="text" id="adminServerFolderPath" class="form-control" 
                               value="C:\\Users\\Abishek\\OneDrive\\Desktop\\all in\\Attendance_Marker\\dataset" 
                               placeholder="e.g. C:\\Users\\...\\Attendance_Marker\\dataset or dataset/721025149001" style="flex: 1;">
                        <button type="button" class="btn btn-outline-primary" onclick="scanAdminServerFolderPath()">
                            <i class="fa-solid fa-magnifying-glass mr-1"></i> Scan / Preview
                        </button>
                    </div>
                    <div class="small text-muted mt-1">
                        Enter an absolute path to a student folder (e.g. <code>.../721025149001</code>) or a parent dataset containing multiple student folders.
                    </div>
                </div>

                <div class="form-check mb-3">
                    <label class="d-flex align-items-center gap-2 small">
                        <input type="checkbox" id="hostReplaceCheckbox" class="form-check-input">
                        <span><strong>Replace existing templates</strong> (Overwrites existing biometrics for these students. If unchecked, students with templates are safely skipped).</span>
                    </label>
                </div>

                <div id="hostPathPreviewContainer" class="mb-3" style="display: none;"></div>

                <div class="d-flex justify-content-end gap-2 mt-3">
                    <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                    <button type="button" id="hostEnrollBtn" class="btn btn-success" onclick="executeAdminServerPathEnroll()" style="display: none;">
                        <i class="fa-solid fa-id-card-clip mr-1"></i> Enroll Face Templates
                    </button>
                </div>
            </div>

            <!-- Browser Upload Mode -->
            <div id="modeBrowserUpload" class="folder-enroll-mode" style="display: none;">
                <div class="form-group mb-3">
                    <label class="form-label font-bold small mb-1">Select Student Face Folder *</label>
                    <input type="file" id="adminFolderFilesInput" class="form-control" webkitdirectory directory multiple onchange="handleAdminFolderFilesSelect(event)">
                    <div class="small text-muted mt-1">
                        Select a folder whose name is the student's register number, or a parent folder containing student register number subdirectories.
                    </div>
                </div>

                <div id="browserFolderStats" class="alert alert-secondary py-2 px-3 mb-3 small" style="display: none;"></div>

                <div class="form-check mb-3">
                    <label class="d-flex align-items-center gap-2 small">
                        <input type="checkbox" id="browserReplaceCheckbox" class="form-check-input">
                        <span><strong>Replace existing templates</strong> (Overwrites existing biometrics).</span>
                    </label>
                </div>

                <div class="d-flex justify-content-end gap-2 mt-3">
                    <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                    <button type="button" id="browserEnrollBtn" class="btn btn-primary" onclick="executeAdminFolderUpload()" disabled>
                        <i class="fa-solid fa-cloud-arrow-up mr-1"></i> Upload & Enroll
                    </button>
                </div>
            </div>

            <!-- Progress & Results Container -->
            <div id="folderEnrollProgressContainer" class="mt-3" style="display: none;"></div>
            <div id="folderEnrollResultsContainer" class="mt-3" style="display: none;"></div>
        </div>
    `;

    openAdminModal('Admin Folder-Based Face Enrollment', body);
}

function switchFolderEnrollMode(mode) {
    const hostEl = document.getElementById('modeHostPath');
    const browserEl = document.getElementById('modeBrowserUpload');
    const tabHost = document.getElementById('tabBtnHostPath');
    const tabBrowser = document.getElementById('tabBtnBrowserUpload');
    const previewContainer = document.getElementById('hostPathPreviewContainer');
    const resultsContainer = document.getElementById('folderEnrollResultsContainer');

    if (resultsContainer) resultsContainer.style.display = 'none';

    if (mode === 'host') {
        if (hostEl) hostEl.style.display = 'block';
        if (browserEl) browserEl.style.display = 'none';
        if (tabHost) {
            tabHost.classList.remove('btn-secondary');
            tabHost.classList.add('btn-primary');
        }
        if (tabBrowser) {
            tabBrowser.classList.remove('btn-primary');
            tabBrowser.classList.add('btn-secondary');
        }
    } else {
        if (hostEl) hostEl.style.display = 'none';
        if (browserEl) browserEl.style.display = 'block';
        if (tabHost) {
            tabHost.classList.remove('btn-primary');
            tabHost.classList.add('btn-secondary');
        }
        if (tabBrowser) {
            tabBrowser.classList.remove('btn-secondary');
            tabBrowser.classList.add('btn-primary');
        }
    }
}

function handleAdminFolderFilesSelect(event) {
    const files = event.target.files;
    selectedFolderFiles = Array.from(files || []);

    const statsEl = document.getElementById('browserFolderStats');
    const enrollBtn = document.getElementById('browserEnrollBtn');

    if (!selectedFolderFiles || selectedFolderFiles.length === 0) {
        if (statsEl) statsEl.style.display = 'none';
        if (enrollBtn) enrollBtn.disabled = true;
        return;
    }

    const supportedExts = ['.jpg', '.jpeg', '.png', '.webp'];
    const imageFiles = selectedFolderFiles.filter(f => {
        const ext = (f.name.substring(f.name.lastIndexOf('.')) || '').toLowerCase();
        return supportedExts.includes(ext);
    });

    const folderNames = new Set();
    selectedFolderFiles.forEach(f => {
        const path = f.webkitRelativePath || f.name;
        const parts = path.split('/');
        if (parts.length > 1) {
            for (let i = 0; i < parts.length - 1; i++) {
                if (/^[A-Za-z0-9_-]+$/.test(parts[i])) {
                    folderNames.add(parts[i]);
                }
            }
        }
    });

    if (statsEl) {
        statsEl.style.display = 'block';
        statsEl.innerHTML = `
            <div><strong>Selected:</strong> ${selectedFolderFiles.length} file(s) (${imageFiles.length} valid images).</div>
            <div class="text-muted mt-1">Detected potential student folder keys: <code>${Array.from(folderNames).slice(0, 5).join(', ')}${folderNames.size > 5 ? '...' : ''}</code></div>
        `;
    }

    if (enrollBtn) {
        enrollBtn.disabled = imageFiles.length === 0;
    }
}

async function scanAdminServerFolderPath() {
    const pathInput = document.getElementById('adminServerFolderPath');
    const previewContainer = document.getElementById('hostPathPreviewContainer');
    const enrollBtn = document.getElementById('hostEnrollBtn');

    const folderPath = (pathInput ? pathInput.value : '').trim();
    if (!folderPath) {
        showToast('Please specify a directory path', 'warning');
        return;
    }

    if (previewContainer) {
        previewContainer.style.display = 'block';
        previewContainer.innerHTML = '<div class="text-center p-3 text-muted"><i class="fa-solid fa-spinner fa-spin mr-2"></i> Scanning folder hierarchy and matching registered students...</div>';
    }
    if (enrollBtn) enrollBtn.style.display = 'none';

    try {
        const data = await apiFetch('/api/v1/admin/preview-folder-path', {
            method: 'POST',
            body: JSON.stringify({ folder_path: folderPath })
        });

        let rowsHtml = '';
        data.students.forEach(st => {
            const badgeClass = st.exists_in_db ? 'badge-success' : 'badge-danger';
            const statusText = st.exists_in_db ? 'Registered in DB' : 'Not Found in DB';
            const templateInfo = st.exists_in_db ? `${st.current_template_count} template(s)` : 'N/A';
            rowsHtml += `
                <tr>
                    <td><strong>${escapeHtml(st.roll_number)}</strong></td>
                    <td>${st.full_name ? escapeHtml(st.full_name) : '<span class="text-muted">--</span>'}</td>
                    <td>${st.class_name ? escapeHtml(st.class_name) : '<span class="text-muted">--</span>'}</td>
                    <td><span class="badge ${badgeClass}">${statusText}</span></td>
                    <td>${st.image_files_count} photo(s)</td>
                    <td>${templateInfo}</td>
                </tr>
            `;
        });

        previewContainer.innerHTML = `
            <div class="card p-3 mb-2" style="background: rgba(15, 23, 42, 0.6); border: 1px solid rgba(255,255,255,0.08); border-radius: 8px;">
                <div class="d-flex justify-content-between align-items-center mb-2">
                    <h6 class="mb-0 font-bold"><i class="fa-solid fa-list-check mr-1 text-primary"></i> Pre-flight Manifest</h6>
                    <span class="small text-muted">${data.students_found_in_db} / ${data.total_folders} students identified</span>
                </div>
                <div class="small mb-2 text-muted">
                    Found <strong>${data.total_image_files}</strong> candidate image(s) across <strong>${data.total_folders}</strong> student folder(s). Ignored ${data.ignored_non_image_files} non-image file(s).
                </div>
                <div class="table-responsive" style="max-height: 220px; overflow-y: auto;">
                    <table class="table table-sm table-dark table-hover mb-0" style="font-size: 0.82rem;">
                        <thead>
                            <tr>
                                <th>Roll Number</th>
                                <th>Name</th>
                                <th>Class</th>
                                <th>DB Status</th>
                                <th>Photos</th>
                                <th>Current Biometrics</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${rowsHtml}
                        </tbody>
                    </table>
                </div>
            </div>
        `;

        if (enrollBtn && data.students_found_in_db > 0) {
            enrollBtn.style.display = 'inline-block';
        }
    } catch (err) {
        if (previewContainer) {
            previewContainer.innerHTML = `<div class="alert alert-danger py-2 px-3 small">${escapeHtml(err.message || 'Failed to inspect path')}</div>`;
        }
        if (enrollBtn) enrollBtn.style.display = 'none';
    }
}

async function executeAdminServerPathEnroll() {
    const pathInput = document.getElementById('adminServerFolderPath');
    const replaceCheckbox = document.getElementById('hostReplaceCheckbox');
    const enrollBtn = document.getElementById('hostEnrollBtn');
    const progressContainer = document.getElementById('folderEnrollProgressContainer');
    const resultsContainer = document.getElementById('folderEnrollResultsContainer');

    const folderPath = (pathInput ? pathInput.value : '').trim();
    const isReplace = replaceCheckbox ? replaceCheckbox.checked : false;

    if (!folderPath) {
        showToast('Please specify folder path', 'warning');
        return;
    }

    if (enrollBtn) enrollBtn.disabled = true;
    if (progressContainer) {
        progressContainer.style.display = 'block';
        progressContainer.innerHTML = `
            <div class="alert alert-info py-3 text-center">
                <i class="fa-solid fa-circle-notch fa-spin fa-2x mb-2 text-primary"></i>
                <div><strong>Processing Biometric Enrollment Pipeline...</strong></div>
                <div class="small text-muted mt-1">Detecting faces and computing 128-d biometric feature vectors. Please do not close this window.</div>
            </div>
        `;
    }
    if (resultsContainer) resultsContainer.style.display = 'none';

    try {
        const data = await apiFetch('/api/v1/admin/enroll-folder-path', {
            method: 'POST',
            body: JSON.stringify({
                folder_path: folderPath,
                replace: isReplace
            })
        });

        if (progressContainer) progressContainer.style.display = 'none';
        renderFolderEnrollResults(data);
        showToast(data.message || 'Folder enrollment completed', 'success');
    } catch (err) {
        if (progressContainer) {
            progressContainer.innerHTML = `<div class="alert alert-danger py-2 px-3 small">${escapeHtml(err.message || 'Enrollment failed')}</div>`;
        }
        if (enrollBtn) enrollBtn.disabled = false;
    }
}

async function executeAdminFolderUpload() {
    const replaceCheckbox = document.getElementById('browserReplaceCheckbox');
    const enrollBtn = document.getElementById('browserEnrollBtn');
    const progressContainer = document.getElementById('folderEnrollProgressContainer');
    const resultsContainer = document.getElementById('folderEnrollResultsContainer');

    if (!selectedFolderFiles || selectedFolderFiles.length === 0) {
        showToast('No files selected', 'warning');
        return;
    }

    const isReplace = replaceCheckbox ? replaceCheckbox.checked : false;

    if (enrollBtn) enrollBtn.disabled = true;
    if (progressContainer) {
        progressContainer.style.display = 'block';
        progressContainer.innerHTML = `
            <div class="alert alert-info py-3 text-center">
                <i class="fa-solid fa-circle-notch fa-spin fa-2x mb-2 text-primary"></i>
                <div><strong>Uploading and processing face photos...</strong></div>
                <div class="small text-muted mt-1">Validating facial quality and extracting biometric embeddings.</div>
            </div>
        `;
    }
    if (resultsContainer) resultsContainer.style.display = 'none';

    try {
        const formData = new FormData();
        const pathsList = [];

        selectedFolderFiles.forEach(file => {
            formData.append('files', file);
            pathsList.push(file.webkitRelativePath || file.name);
        });

        formData.append('paths_json', JSON.stringify(pathsList));
        formData.append('replace', isReplace ? 'true' : 'false');

        const token = localStorage.getItem('access_token');
        const headers = {};
        if (token) headers['Authorization'] = `Bearer ${token}`;

        const res = await fetch('/api/v1/admin/enroll-folder', {
            method: 'POST',
            headers,
            body: formData
        });

        const data = await res.json();
        if (!res.ok) {
            throw new Error(data.detail || data.message || 'Folder upload enrollment failed');
        }

        if (progressContainer) progressContainer.style.display = 'none';
        renderFolderEnrollResults(data);
        showToast(data.message || 'Folder enrollment completed', 'success');
    } catch (err) {
        if (progressContainer) {
            progressContainer.innerHTML = `<div class="alert alert-danger py-2 px-3 small">${escapeHtml(err.message || 'Upload failed')}</div>`;
        }
        if (enrollBtn) enrollBtn.disabled = false;
    }
}

function renderFolderEnrollResults(data) {
    const resultsContainer = document.getElementById('folderEnrollResultsContainer');
    if (!resultsContainer) return;

    let studentsCardsHtml = '';
    (data.students || []).forEach(st => {
        let badgeColor = 'badge-success';
        if (st.status === 'PARTIAL_SUCCESS') badgeColor = 'badge-warning';
        else if (st.status === 'SKIPPED_ALREADY_ENROLLED') badgeColor = 'badge-info';
        else if (st.status === 'STUDENT_NOT_FOUND' || st.status === 'NO_VALID_IMAGES') badgeColor = 'badge-danger';

        let itemsSummary = '';
        if (st.items && st.items.length > 0) {
            itemsSummary = '<ul class="list-unstyled mb-0 mt-1 small" style="opacity: 0.85;">' +
                st.items.map(item => {
                    const icon = item.status === 'ENROLLED' ? '<i class="fa-solid fa-check text-success mr-1"></i>' : '<i class="fa-solid fa-xmark text-danger mr-1"></i>';
                    const detail = item.reason ? ` <span class="text-muted">(${escapeHtml(item.reason)})</span>` : '';
                    return `<li>${icon}<code>${escapeHtml(item.filename)}</code>: <strong>${item.status}</strong>${detail}</li>`;
                }).join('') +
                '</ul>';
        }

        studentsCardsHtml += `
            <div class="card p-2 mb-2" style="background: rgba(30, 41, 59, 0.5); border: 1px solid rgba(255,255,255,0.06); border-radius: 6px;">
                <div class="d-flex justify-content-between align-items-center">
                    <div>
                        <strong>${escapeHtml(st.roll_number)}</strong>
                        ${st.full_name ? ` <span class="text-muted">(${escapeHtml(st.full_name)})</span>` : ''}
                    </div>
                    <span class="badge ${badgeColor}">${escapeHtml(st.status)}</span>
                </div>
                <div class="small text-muted mt-1">
                    Enrolled: <strong>${st.valid_enrolled}</strong> / ${st.total_files} | Rejected: ${st.rejected} ${st.replaced_old_count > 0 ? `| Replaced: ${st.replaced_old_count}` : ''}
                </div>
                ${itemsSummary}
            </div>
        `;
    });

    resultsContainer.style.display = 'block';
    resultsContainer.innerHTML = `
        <div class="card p-3" style="background: rgba(15, 23, 42, 0.8); border: 1px solid rgba(59, 130, 246, 0.3); border-radius: 8px;">
            <div class="d-flex justify-content-between align-items-center mb-2">
                <h6 class="mb-0 font-bold text-success"><i class="fa-solid fa-circle-check mr-1"></i> Batch Enrollment Complete</h6>
                <button type="button" class="btn btn-sm btn-primary" onclick="closeAdminModal(); loadBiometricsTab();">
                    <i class="fa-solid fa-rotate-right mr-1"></i> Done & Refresh Biometrics
                </button>
            </div>
            <div class="d-flex gap-3 my-2 small text-muted border-top border-bottom py-2">
                <div>Total Folders: <strong>${data.total_folders}</strong></div>
                <div>Files Processed: <strong>${data.total_files_processed}</strong></div>
                <div>Students Succeeded: <strong class="text-success">${data.successful_students}</strong></div>
                <div>Students Failed/Skipped: <strong class="text-danger">${data.failed_students}</strong></div>
                <div>Templates Created: <strong class="text-primary">${data.total_embeddings_created}</strong></div>
            </div>
            <div class="mt-2" style="max-height: 260px; overflow-y: auto;">
                ${studentsCardsHtml}
            </div>
        </div>
    `;
}


// ====================================================
// TAB: CENTRAL USER ACCOUNTS & ACCESS CONTROL
// ====================================================
async function loadUsersTab() {
    try {
        const roleVal = document.getElementById('userRoleFilter')?.value;
        const statusVal = document.getElementById('userStatusFilter')?.value;

        const params = new URLSearchParams();
        if (roleVal) params.append('role', roleVal);
        if (statusVal !== "" && statusVal !== undefined) params.append('is_active', statusVal);

        const users = await apiFetch(`/api/v1/admin/users?${params.toString()}`);
        cachedUsers = users;
        renderUsersTable();
    } catch (e) {
        showToast("Failed to load user accounts", "danger");
    }
}

function renderUsersTable() {
    const searchVal = (document.getElementById('userSearch')?.value || '').toLowerCase().trim();
    const tbody = document.querySelector('#usersTable tbody');
    if (!tbody) return;

    const filtered = cachedUsers.filter(u => {
        const text = `${u.username || ''} ${u.email || ''} ${u.login_identifier || ''} ${u.role || ''}`.toLowerCase();
        return text.includes(searchVal);
    });

    if (filtered.length === 0) {
        tbody.innerHTML = '<tr><td colspan="9" class="text-center text-muted">No user accounts found.</td></tr>';
        return;
    }

    tbody.innerHTML = filtered.map(u => {
        let roleBadge = 'badge-info';
        if (u.role === 'ADMIN') roleBadge = 'badge-danger';
        else if (u.role === 'FACULTY') roleBadge = 'badge-primary';

        const statusBadge = u.is_active
            ? '<span class="badge badge-success"><i class="fa-solid fa-circle-check"></i> Active</span>'
            : '<span class="badge badge-danger"><i class="fa-solid fa-ban"></i> Disabled</span>';

        const forceBadge = u.force_password_change
            ? '<span class="badge badge-warning">Required</span>'
            : '<span class="badge badge-secondary">No</span>';

        const lockBadge = u.locked_until
            ? '<span class="badge badge-danger">Locked</span>'
            : '<span class="badge badge-success">Normal</span>';

        return `
            <tr>
                <td>#${u.id}</td>
                <td><strong>${escapeHtml(u.username)}</strong><br><small class="text-muted">${escapeHtml(u.login_identifier || '')}</small></td>
                <td>${escapeHtml(u.email || '—')}</td>
                <td><span class="badge ${roleBadge}">${u.role}</span></td>
                <td>${statusBadge}</td>
                <td>${forceBadge}</td>
                <td>${lockBadge}</td>
                <td><small class="text-muted">${formatDate(u.created_at)}</small></td>
                <td>
                    <div class="btn-group gap-1">
                        <button class="btn btn-sm btn-outline-secondary" onclick="openEditUserModal(${u.id})" title="Edit Account">
                            <i class="fa-solid fa-pen"></i>
                        </button>
                        <button class="btn btn-sm ${u.is_active ? 'btn-outline-danger' : 'btn-outline-success'}" onclick="toggleUserActive(${u.id}, ${u.is_active})" title="${u.is_active ? 'Disable Account' : 'Enable Account'}">
                            <i class="fa-solid ${u.is_active ? 'fa-user-slash' : 'fa-user-check'}"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-warning" onclick="openResetUserPasswordModal(${u.id}, '${escapeHtml(u.username)}')" title="Reset Password">
                            <i class="fa-solid fa-key"></i>
                        </button>
                    </div>
                </td>
            </tr>
        `;
    }).join('');
}

function openEditUserModal(userId) {
    const user = cachedUsers.find(u => u.id === userId);
    if (!user) return;

    const body = `
        <form id="editUserForm">
            <div class="grid-2-col gap-3">
                <div class="form-group">
                    <label>Username *</label>
                    <input type="text" id="editUsrUsername" class="form-control" required value="${escapeHtml(user.username)}">
                </div>
                <div class="form-group">
                    <label>Email</label>
                    <input type="email" id="editUsrEmail" class="form-control" value="${escapeHtml(user.email || '')}">
                </div>
            </div>

            <div class="form-group mt-2">
                <label>System Role</label>
                <select id="editUsrRole" class="form-control">
                    <option value="ADMIN" ${user.role === 'ADMIN' ? 'selected' : ''}>ADMIN</option>
                    <option value="FACULTY" ${user.role === 'FACULTY' ? 'selected' : ''}>FACULTY</option>
                    <option value="STUDENT" ${user.role === 'STUDENT' ? 'selected' : ''}>STUDENT</option>
                </select>
            </div>

            <div class="form-group mt-3">
                <label>Security & Status</label>
                <div class="flex flex-col gap-2 mt-1">
                    <label class="d-flex align-center gap-2 font-normal">
                        <input type="checkbox" id="editUsrActive" ${user.is_active ? 'checked' : ''}>
                        <span>Account Active</span>
                    </label>
                    <label class="d-flex align-center gap-2 font-normal text-muted small">
                        <input type="checkbox" id="editUsrForcePw" ${user.force_password_change ? 'checked' : ''}>
                        <span>Require password change on next login</span>
                    </label>
                    ${user.locked_until ? `
                    <label class="d-flex align-center gap-2 font-normal text-warning small">
                        <input type="checkbox" id="editUsrUnlock" checked>
                        <span>Unlock Account & Clear Failed Attempts</span>
                    </label>` : ''}
                    <div class="mt-2">
                        <label class="small text-muted">Set New Password (optional, leave blank to keep unchanged):</label>
                        <input type="password" id="editUsrNewPw" class="form-control" placeholder="Enter new password">
                    </div>
                </div>
            </div>

            <div class="modal-actions mt-4">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="submit" class="btn btn-primary"><i class="fa-solid fa-save"></i> Save Changes</button>
            </div>
        </form>
    `;
    openAdminModal(`Edit User Account #${userId} (${user.username})`, body);

    document.getElementById('editUserForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const payload = {
            username: document.getElementById('editUsrUsername').value.trim(),
            email: document.getElementById('editUsrEmail').value.trim() || null,
            role: document.getElementById('editUsrRole').value,
            is_active: document.getElementById('editUsrActive').checked,
            force_password_change: document.getElementById('editUsrForcePw').checked
        };
        const unlockChk = document.getElementById('editUsrUnlock');
        if (unlockChk && unlockChk.checked) {
            payload.unlock = true;
        }
        const newPw = document.getElementById('editUsrNewPw').value;
        if (newPw) {
            payload.new_password = newPw;
        }

        try {
            await apiFetch(`/api/v1/admin/users/${userId}`, {
                method: 'PUT',
                body: JSON.stringify(payload)
            });
            showToast("User account updated successfully", "success");
            closeAdminModal();
            loadUsersTab();
        } catch (err) {
            showToast(err.message || "Failed to update user account", "danger");
        }
    });
}

async function toggleUserActive(userId, currentActive) {
    const action = currentActive ? "disable" : "enable";
    if (!confirm(`Are you sure you want to ${action} user #${userId}?`)) return;
    try {
        const res = await apiFetch(`/api/v1/admin/users/${userId}/toggle-active`, { method: 'POST' });
        showToast(res.message || `User account ${action}d successfully`, "success");
        loadUsersTab();
    } catch (err) {
        showToast(err.message || `Failed to ${action} user`, "danger");
    }
}

function openResetUserPasswordModal(userId, username) {
    const body = `
        <form id="resetUserPwForm">
            <p class="text-muted">Reset credentials for User <strong>${escapeHtml(username)}</strong> (#${userId}):</p>
            
            <div class="form-group mt-3">
                <label>Reset Options</label>
                <div class="flex flex-col gap-2 mt-1">
                    <label class="d-flex align-center gap-2 font-normal">
                        <input type="checkbox" id="usrResetGenerateTemp" checked onchange="toggleCustomPasswordInput(this, 'usrResetCustomPwBox')">
                        <span>Generate Cryptographically Secure Temporary Password <em>(Recommended)</em></span>
                    </label>
                    <div id="usrResetCustomPwBox" style="display: none;" class="mt-1">
                        <input type="password" id="usrResetNewPw" class="form-control" placeholder="Enter custom new password">
                    </div>
                    <label class="d-flex align-center gap-2 font-normal text-muted small">
                        <input type="checkbox" id="usrResetForcePw" checked>
                        <span>Require password change on next login</span>
                    </label>
                </div>
            </div>

            <div class="modal-actions mt-4">
                <button type="button" class="btn btn-secondary" onclick="closeAdminModal()">Cancel</button>
                <button type="submit" class="btn btn-warning"><i class="fa-solid fa-key"></i> Reset Password</button>
            </div>
        </form>
    `;
    openAdminModal(`Reset Password — ${username}`, body);

    document.getElementById('resetUserPwForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const generateTemp = document.getElementById('usrResetGenerateTemp').checked;
        const customPw = document.getElementById('usrResetNewPw').value;

        const payload = {
            generate_temporary: generateTemp,
            new_password: generateTemp ? null : customPw,
            force_password_change: document.getElementById('usrResetForcePw').checked
        };

        try {
            const res = await apiFetch(`/api/v1/admin/users/${userId}/reset-password`, {
                method: 'POST',
                body: JSON.stringify(payload)
            });
            showToast("Password reset successfully", "success");
            closeAdminModal();

            if (res.temporary_password) {
                showTemporaryPasswordModal('User', username, res.temporary_password);
            }
        } catch (err) {
            showToast(err.message || "Failed to reset password", "danger");
        }
    });
}

// ============================================================================
// Phase 11 — Push Notification Center & Class Reminders Controller
// ============================================================================

async function loadNotificationsTab() {
    await Promise.allSettled([
        loadNotificationSettings(),
        loadNotificationClasses(),
        loadScheduledNotifications(),
        loadNotificationLogs()
    ]);
}

async function loadNotificationSettings() {
    let metrics = null;
    try {
        metrics = await apiFetch('/api/v1/admin/notifications/metrics');
    } catch (err) {
        console.warn("Metrics endpoint failed, falling back to settings:", err);
    }

    try {
        const settings = metrics || await apiFetch('/api/v1/admin/notifications/settings');
        
        // Populate form inputs
        const stuEnabled = document.getElementById('notifStudentEnabled');
        if (stuEnabled) stuEnabled.checked = !!settings.student_next_class_enabled;

        const stuLead = document.getElementById('notifStudentLead');
        if (stuLead && settings.student_next_class_lead_minutes) {
            stuLead.value = String(settings.student_next_class_lead_minutes);
        }

        const facEnabled = document.getElementById('notifFacultyEnabled');
        if (facEnabled) facEnabled.checked = !!settings.faculty_next_class_enabled;

        const facLead = document.getElementById('notifFacultyLead');
        if (facLead && settings.faculty_next_class_lead_minutes) {
            facLead.value = String(settings.faculty_next_class_lead_minutes);
        }

        const attEnabled = document.getElementById('notifAttendanceEnabled');
        if (attEnabled) attEnabled.checked = !!settings.attendance_status_enabled;

        const annEnabled = document.getElementById('notifAnnouncementsEnabled');
        if (annEnabled) annEnabled.checked = !!settings.admin_announcements_enabled;

        // Update Overview Metric Cards
        const statStu = document.getElementById('statNotifStudentStatus');
        if (statStu) {
            statStu.innerHTML = settings.student_next_class_enabled 
                ? `<span class="text-success">Active (${settings.student_next_class_lead_minutes}m)</span>`
                : `<span class="text-muted">Disabled</span>`;
        }

        const statFac = document.getElementById('statNotifFacultyStatus');
        if (statFac) {
            statFac.innerHTML = settings.faculty_next_class_enabled 
                ? `<span class="text-warning">Active (${settings.faculty_next_class_lead_minutes}m)</span>`
                : `<span class="text-muted">Disabled</span>`;
        }

        const statDevices = document.getElementById('statNotifDevices');
        if (statDevices) {
            if (metrics && typeof metrics.active_device_tokens === 'number') {
                statDevices.innerText = `${metrics.active_device_tokens} Active`;
            }
        }

        const statLogs = document.getElementById('statNotifTotalLogs');
        if (statLogs) {
            if (metrics && typeof metrics.total_dispatched_logs === 'number') {
                statLogs.innerText = String(metrics.total_dispatched_logs);
            }
        }
    } catch (err) {
        console.error("Failed to load notification settings:", err);
        const statStu = document.getElementById('statNotifStudentStatus');
        if (statStu) statStu.innerHTML = `<span class="text-danger">Load Error</span>`;
        const statFac = document.getElementById('statNotifFacultyStatus');
        if (statFac) statFac.innerHTML = `<span class="text-danger">Load Error</span>`;
        showToast("Error loading notification settings: " + (err.message || 'Network error'), "danger");
    }

    // Fallback device count if metrics wasn't available
    if (!metrics) {
        try {
            const users = await apiFetch('/api/v1/admin/users?limit=200');
            const statDevices = document.getElementById('statNotifDevices');
            if (statDevices && statDevices.innerText === '--') {
                statDevices.innerText = users ? `${users.length} Enrolled` : '--';
            }
        } catch (e) {}
    }
}

async function handleSaveNotificationSettings(e) {
    if (e) e.preventDefault();
    const btn = document.getElementById('btnSaveNotifSettings');
    if (btn) btn.disabled = true;

    const payload = {
        student_next_class_enabled: document.getElementById('notifStudentEnabled').checked,
        student_next_class_lead_minutes: parseInt(document.getElementById('notifStudentLead').value, 10),
        faculty_next_class_enabled: document.getElementById('notifFacultyEnabled').checked,
        faculty_next_class_lead_minutes: parseInt(document.getElementById('notifFacultyLead').value, 10),
        attendance_status_enabled: document.getElementById('notifAttendanceEnabled').checked,
        admin_announcements_enabled: document.getElementById('notifAnnouncementsEnabled').checked,
    };

    try {
        await apiFetch('/api/v1/admin/notifications/settings', {
            method: 'PUT',
            body: JSON.stringify(payload)
        });
        showToast("Notification settings saved successfully", "success");
        await loadNotificationSettings();
    } catch (err) {
        showToast(err.message || "Failed to save notification settings", "danger");
    } finally {
        if (btn) btn.disabled = false;
    }
}

async function triggerManualReminderCheck() {
    const resAlert = document.getElementById('manualReminderResult');
    const timeInput = document.getElementById('notifSimulateTime');
    const refTime = timeInput ? timeInput.value.trim() : '';

    let url = '/api/v1/admin/notifications/trigger-reminders';
    if (refTime) {
        url += `?reference_time=${encodeURIComponent(refTime)}`;
    }

    if (resAlert) {
        resAlert.className = 'alert alert-info mt-3';
        resAlert.innerHTML = '<i class="fa-solid fa-spinner fa-spin mr-1"></i> Running timetable reminder window evaluation...';
        resAlert.classList.remove('hidden');
    }

    try {
        const result = await apiFetch(url, { method: 'POST' });
        if (resAlert) {
            resAlert.className = 'alert alert-success mt-3';
            resAlert.innerHTML = `
                <strong><i class="fa-solid fa-circle-check text-success"></i> Check Finished (${result.current_time} ${result.timezone}):</strong><br>
                &bull; Students: <strong>${result.student_reminders_sent}</strong> sent, <strong>${result.student_reminders_skipped}</strong> skipped.<br>
                &bull; Faculty: <strong>${result.faculty_reminders_sent}</strong> sent, <strong>${result.faculty_reminders_skipped}</strong> skipped.
            `;
        }
        showToast(`Reminders check completed (${result.student_reminders_sent + result.faculty_reminders_sent} sent)`, "success");
        await loadNotificationLogs();
    } catch (err) {
        if (resAlert) {
            resAlert.className = 'alert alert-danger mt-3';
            resAlert.innerHTML = `<i class="fa-solid fa-circle-xmark mr-1"></i> Error: ${escapeHtml(err.message || 'Evaluation failed')}`;
        }
    }
}

async function loadNotificationClasses() {
    const classSelect = document.getElementById('notifTargetClass');
    if (!classSelect) return;

    try {
        const classes = await apiFetch('/api/v1/admin/classes');
        classSelect.innerHTML = '<option value="">Select class section...</option>';
        classes.forEach(c => {
            const opt = document.createElement('option');
            opt.value = c.name;
            opt.textContent = `${c.name} (${c.department || 'General'})`;
            classSelect.appendChild(opt);
        });
    } catch (err) {
        console.error("Failed to load classes for notification composer:", err);
    }
}

function handleAudienceChange() {
    const audience = document.getElementById('notifAudience').value;
    const targetType = document.getElementById('notifTargetType');
    
    if (targetType) {
        if (audience === 'ALL') {
            targetType.value = 'ALL';
        }
    }
    handleTargetTypeChange();
}

function handleTargetTypeChange() {
    const targetType = document.getElementById('notifTargetType').value;
    const classGroup = document.getElementById('notifClassGroup');
    const userGroup = document.getElementById('notifUserGroup');

    if (classGroup) {
        if (targetType === 'CLASS') {
            classGroup.classList.remove('hidden');
        } else {
            classGroup.classList.add('hidden');
        }
    }

    if (userGroup) {
        if (targetType === 'USER') {
            userGroup.classList.remove('hidden');
        } else {
            userGroup.classList.add('hidden');
        }
    }
}

function insertNotifVar(varToken) {
    const bodyField = document.getElementById('notifBody');
    if (!bodyField) return;

    const start = bodyField.selectionStart || bodyField.value.length;
    const end = bodyField.selectionEnd || bodyField.value.length;
    const text = bodyField.value;

    bodyField.value = text.substring(0, start) + varToken + text.substring(end);
    bodyField.focus();
    bodyField.selectionStart = bodyField.selectionEnd = start + varToken.length;
}

function toggleTimingPicker() {
    const isSchedule = document.getElementById('timingSchedule').checked;
    const picker = document.getElementById('notifSchedulePicker');
    if (picker) {
        if (isSchedule) {
            picker.classList.remove('hidden');
            const dateInput = document.getElementById('notifScheduledAt');
            if (dateInput && !dateInput.value) {
                const now = new Date(Date.now() + 60 * 60 * 1000);
                now.setMinutes(now.getMinutes() - now.getTimezoneOffset());
                dateInput.value = now.toISOString().slice(0, 16);
            }
        } else {
            picker.classList.add('hidden');
        }
    }
}

async function handleSendCustomNotification(e) {
    if (e) e.preventDefault();
    const btn = document.getElementById('btnSendNotif');
    const resAlert = document.getElementById('notifComposerResult');

    const audience = document.getElementById('notifAudience').value;
    const targetType = document.getElementById('notifTargetType').value;
    let targetId = null;

    if (targetType === 'CLASS') {
        targetId = document.getElementById('notifTargetClass').value.trim();
        if (!targetId) {
            showToast("Please select a target class section", "warning");
            return;
        }
    } else if (targetType === 'USER') {
        targetId = document.getElementById('notifTargetUser').value.trim();
        if (!targetId) {
            showToast("Please enter a user ID or roll number", "warning");
            return;
        }
    }

    const title = document.getElementById('notifTitle').value.trim();
    const body = document.getElementById('notifBody').value.trim();
    const channel = document.getElementById('notifChannel').value;
    const priority = document.getElementById('notifPriority').value;
    const route = document.getElementById('notifRoute').value;

    if (!title || !body) {
        showToast("Title and message body are required", "warning");
        return;
    }

    let scheduledAt = null;
    const isSchedule = document.getElementById('timingSchedule').checked;
    if (isSchedule) {
        const schedVal = document.getElementById('notifScheduledAt').value;
        if (!schedVal) {
            showToast("Please select a date and time for scheduled delivery", "warning");
            return;
        }
        scheduledAt = new Date(schedVal).toISOString();
    }

    const payload = {
        audience: audience,
        target_type: targetType,
        target_id: targetId,
        title: title,
        body: body,
        channel: channel,
        priority: priority,
        route: route,
        scheduled_at: scheduledAt
    };

    if (btn) btn.disabled = true;
    if (resAlert) {
        resAlert.className = 'alert alert-info mb-3';
        resAlert.innerHTML = '<i class="fa-solid fa-spinner fa-spin mr-1"></i> Processing broadcast dispatch...';
        resAlert.classList.remove('hidden');
    }

    try {
        const res = await apiFetch('/api/v1/admin/notifications/send', {
            method: 'POST',
            body: JSON.stringify(payload)
        });

        if (resAlert) {
            if (res.status === 'SCHEDULED') {
                resAlert.className = 'alert alert-info mb-3';
                resAlert.innerHTML = `<strong><i class="fa-solid fa-calendar-check mr-1"></i> Scheduled:</strong> ${escapeHtml(res.message || 'Queued for delivery')}`;
            } else if (res.devices_sent > 0) {
                resAlert.className = 'alert alert-success mb-3';
                resAlert.innerHTML = `<strong><i class="fa-solid fa-circle-check mr-1"></i> Push Sent:</strong> Recorded for ${res.recipients_count} recipient(s) &amp; dispatched ${res.devices_sent} push notification(s) (${res.devices_failed || 0} failed).`;
            } else {
                resAlert.className = 'alert alert-warning mb-3';
                resAlert.innerHTML = `<strong><i class="fa-solid fa-box-archive mr-1"></i> Stored in In-App Inbox:</strong> Stored for ${res.recipients_count} recipient(s). No active push device tokens registered for these recipients.`;
            }
        }
        showToast(res.status === 'SCHEDULED' ? "Notification scheduled" : `Broadcast processed: ${res.recipients_count} in-app, ${res.devices_sent || 0} pushed`, "success");

        document.getElementById('notifTitle').value = '';
        document.getElementById('notifBody').value = '';

        await loadScheduledNotifications();
        await loadNotificationLogs();
    } catch (err) {
        if (resAlert) {
            resAlert.className = 'alert alert-danger mb-3';
            resAlert.innerHTML = `<i class="fa-solid fa-triangle-exclamation mr-1"></i> Error: ${escapeHtml(err.message || 'Dispatch failed')}`;
        }
        showToast(err.message || "Failed to dispatch notification", "danger");
    } finally {
        if (btn) btn.disabled = false;
    }
}

async function loadScheduledNotifications() {
    const tbody = document.querySelector('#scheduledNotificationsTable tbody');
    if (!tbody) return;

    tbody.innerHTML = '<tr><td colspan="7" class="text-center text-muted"><i class="fa-solid fa-spinner fa-spin mr-2"></i>Loading scheduled broadcasts...</td></tr>';

    try {
        const list = await apiFetch('/api/v1/admin/notifications/scheduled?status_filter=PENDING');
        if (!list || list.length === 0) {
            tbody.innerHTML = '<tr><td colspan="7" class="text-center text-muted"><i class="fa-solid fa-inbox mr-2"></i>No pending scheduled broadcasts in queue.</td></tr>';
            return;
        }

        tbody.innerHTML = list.map(item => {
            const schedDate = new Date(item.scheduled_at);
            const dateStr = schedDate.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
            return `
                <tr>
                    <td><code>#${item.id}</code></td>
                    <td><strong class="text-info">${escapeHtml(dateStr)}</strong></td>
                    <td><strong>${escapeHtml(item.title)}</strong><br><small class="text-muted">${escapeHtml(item.body.slice(0, 50))}</small></td>
                    <td><span class="badge badge-secondary">${escapeHtml(item.audience)}</span> (${escapeHtml(item.target_type)}: ${escapeHtml(item.target_id || 'All')})</td>
                    <td><span class="badge badge-secondary">${escapeHtml(item.channel)}</span></td>
                    <td><span class="badge badge-status-scheduled">${escapeHtml(item.status)}</span></td>
                    <td>
                        <button class="btn btn-sm btn-outline-danger" onclick="cancelScheduledBroadcast(${item.id})">
                            <i class="fa-solid fa-xmark"></i> Cancel
                        </button>
                    </td>
                </tr>
            `;
        }).join('');
    } catch (err) {
        tbody.innerHTML = `<tr><td colspan="7" class="text-center text-danger"><i class="fa-solid fa-triangle-exclamation mr-1"></i> Error loading scheduled notifications: ${escapeHtml(err.message || 'Network error')} <button class="btn btn-sm btn-outline-secondary ml-2" onclick="loadScheduledNotifications()"><i class="fa-solid fa-rotate-right"></i> Retry</button></td></tr>`;
    }
}

async function cancelScheduledBroadcast(id) {
    if (!confirm(`Cancel scheduled broadcast #${id}?`)) return;

    try {
        await apiFetch(`/api/v1/admin/notifications/scheduled/${id}`, { method: 'DELETE' });
        showToast(`Scheduled notification #${id} cancelled`, "success");
        await loadScheduledNotifications();
    } catch (err) {
        showToast(err.message || "Failed to cancel scheduled notification", "danger");
    }
}

async function loadNotificationLogs() {
    const tbody = document.querySelector('#notificationLogsTable tbody');
    if (!tbody) return;

    tbody.innerHTML = '<tr><td colspan="7" class="text-center text-muted"><i class="fa-solid fa-spinner fa-spin mr-2"></i>Loading notification logs...</td></tr>';

    const typeFilter = document.getElementById('notifLogTypeFilter') ? document.getElementById('notifLogTypeFilter').value : '';
    let url = '/api/v1/admin/notifications/logs?limit=100';
    if (typeFilter) {
        url += `&notification_type=${encodeURIComponent(typeFilter)}`;
    }

    try {
        const logs = await apiFetch(url);
        
        const statTotal = document.getElementById('statNotifTotalLogs');
        if (statTotal && !typeFilter) {
            statTotal.innerText = logs ? String(logs.length) : '0';
        }

        if (!logs || logs.length === 0) {
            tbody.innerHTML = '<tr><td colspan="7" class="text-center text-muted"><i class="fa-solid fa-clipboard-list mr-2"></i>No notification logs recorded.</td></tr>';
            return;
        }

        tbody.innerHTML = logs.map(l => {
            const dt = new Date(l.created_at);
            const dateStr = dt.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
            
            let statusBadge = '<span class="badge badge-status-sent">SENT</span>';
            if (l.status === 'PROVIDER_ACCEPTED') {
                statusBadge = '<span class="badge" style="background: rgba(16,185,129,0.15); color: #10b981; border: 1px solid rgba(16,185,129,0.3);"><i class="fa-solid fa-check-double mr-1"></i>FCM ACCEPTED</span>';
            } else if (l.status === 'STORED') {
                statusBadge = '<span class="badge" style="background: rgba(100,116,139,0.15); color: #94a3b8; border: 1px solid rgba(100,116,139,0.3);"><i class="fa-solid fa-box-archive mr-1"></i>IN-APP ONLY</span>';
            } else if (l.status === 'SIMULATED') {
                statusBadge = '<span class="badge" style="background: rgba(14,165,233,0.15); color: #38bdf8; border: 1px solid rgba(14,165,233,0.3);"><i class="fa-solid fa-flask mr-1"></i>SIMULATED</span>';
            } else if (l.status === 'FAILED') {
                statusBadge = '<span class="badge badge-status-failed"><i class="fa-solid fa-xmark mr-1"></i>FAILED</span>';
            } else if (l.status === 'SKIPPED') {
                statusBadge = '<span class="badge badge-status-skipped"><i class="fa-solid fa-forward-step mr-1"></i>SKIPPED</span>';
            } else if (l.status === 'SCHEDULED') {
                statusBadge = '<span class="badge badge-status-scheduled"><i class="fa-solid fa-clock mr-1"></i>SCHEDULED</span>';
            }

            const payloadSafe = l.data_payload ? encodeURIComponent(l.data_payload) : '';

            return `
                <tr>
                    <td><code>#${l.id}</code></td>
                    <td style="white-space: nowrap; font-size: 0.85rem;">${escapeHtml(dateStr)}</td>
                    <td>User #${l.user_id}</td>
                    <td>
                        <span class="badge badge-secondary">${escapeHtml(l.notification_type)}</span><br>
                        <small class="text-muted">${escapeHtml(l.channel_id)}</small>
                    </td>
                    <td>
                        <strong>${escapeHtml(l.title)}</strong><br>
                        <span style="font-size: 0.85rem; color: #cbd5e1;">${escapeHtml(l.body)}</span>
                        ${l.error_message ? `<br><small class="text-danger">${escapeHtml(l.error_message)}</small>` : ''}
                    </td>
                    <td>${statusBadge}</td>
                    <td>
                        ${l.data_payload ? `
                            <button class="btn btn-sm btn-outline-secondary" onclick="showNotificationPayloadModal('${payloadSafe}')">
                                <i class="fa-solid fa-code"></i> Data
                            </button>
                        ` : '<span class="text-muted">&mdash;</span>'}
                    </td>
                </tr>
            `;
        }).join('');
    } catch (err) {
        tbody.innerHTML = `<tr><td colspan="7" class="text-center text-danger"><i class="fa-solid fa-triangle-exclamation mr-1"></i> Error loading notification logs: ${escapeHtml(err.message || 'Network error')} <button class="btn btn-sm btn-outline-secondary ml-2" onclick="loadNotificationLogs()"><i class="fa-solid fa-rotate-right"></i> Retry</button></td></tr>`;
    }
}

function showNotificationPayloadModal(encodedPayload) {
    let formatted = '';
    try {
        const parsed = JSON.parse(decodeURIComponent(encodedPayload));
        formatted = JSON.stringify(parsed, null, 2);
    } catch (e) {
        formatted = decodeURIComponent(encodedPayload);
    }

    const body = `
        <pre class="json-display" style="background: #0b1120; padding: 16px; border-radius: 8px; color: #38bdf8; max-height: 400px; overflow: auto; font-family: monospace;">${escapeHtml(formatted)}</pre>
        <div class="modal-actions mt-3 text-right">
            <button class="btn btn-secondary" onclick="closeAdminModal()">Close</button>
        </div>
    `;
    openAdminModal("Notification Payload", body);
}

