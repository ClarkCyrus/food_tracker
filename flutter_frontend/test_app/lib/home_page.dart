// lib/home_page.dart
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 6),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.more_vert, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, IconData icon) {
    return ListTile(
      leading: CircleAvatar(child: Icon(icon, size: 18)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
          IconButton(icon: const Icon(Icons.account_circle_outlined), onPressed: () {}),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const UserAccountsDrawerHeader(
                accountName: Text('John Doe'),
                accountEmail: Text('john@example.com'),
                currentAccountPicture: CircleAvatar(child: Icon(Icons.person)),
              ),
              ListTile(leading: const Icon(Icons.dashboard), title: const Text('Dashboard'), onTap: () => Navigator.pop(context)),
              ListTile(leading: const Icon(Icons.person), title: const Text('Profile'), onTap: () {}),
              ListTile(leading: const Icon(Icons.settings), title: const Text('Settings'), onTap: () {}),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () => Navigator.pushReplacementNamed(context, '/'),
              ),
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // breakpoints
          final isSmall = width < 600;
          final isMedium = width >= 600 && width < 900;
          final isWide = width >= 900;

          // responsive grid columns
          final statCols = isWide ? 4 : isMedium ? 3 : 2;

          // top padding and spacing tuned for different sizes
          final padding = EdgeInsets.all(isSmall ? 12 : 16);

          return SafeArea(
            child: Padding(
              padding: padding,
              child: Column(
                children: [
                  // Stats grid
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: isSmall ? 200 : 240),
                    child: GridView.builder(
                      itemCount: 4,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: statCols,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 3.2,
                      ),
                      itemBuilder: (context, i) {
                        final items = [
                          () => _buildStatCard('Users', '1,248', Icons.people_outline, Colors.indigo),
                          () => _buildStatCard('Sales', '\$12.4k', Icons.attach_money, Colors.green),
                          () => _buildStatCard('Active', '582', Icons.show_chart, Colors.orange),
                          () => _buildStatCard('Errors', '3', Icons.error_outline, Colors.red),
                        ];
                        return items[i]();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Main content area - responsive: stack on small, two columns on medium/wide
                  Expanded(
                    child: isSmall
                        ? ListView(
                            children: [
                              // Chart card full width
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 12),
                                      AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: Container(
                                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                          child: const Center(child: Text('Chart placeholder', style: TextStyle(color: Colors.black45))),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Recent activity
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Recent Activity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 8),
                                      _buildActivityItem('Order #832', 'Paid \$120', Icons.shopping_bag_outlined),
                                      const Divider(),
                                      _buildActivityItem('New user', 'anna@example.com', Icons.person_add_alt),
                                      const Divider(),
                                      _buildActivityItem('Server restart', '2 hours ago', Icons.restart_alt),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              // Left: main chart (larger)
                              Expanded(
                                flex: 2,
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 12),
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                            child: const Center(child: Text('Chart placeholder', style: TextStyle(color: Colors.black45))),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Right: activities and quick actions
                              Expanded(
                                flex: 1,
                                child: Column(
                                  children: [
                                    Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Recent Activity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 8),
                                            _buildActivityItem('Order #832', 'Paid \$120', Icons.shopping_bag_outlined),
                                            const Divider(),
                                            _buildActivityItem('New user', 'anna@example.com', Icons.person_add_alt),
                                            const Divider(),
                                            _buildActivityItem('Server restart', '2 hours ago', Icons.restart_alt),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: Card(
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: const [
                                              Text('Quick Actions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                              SizedBox(height: 8),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  Chip(label: Text('Create report')),
                                                  Chip(label: Text('Export CSV')),
                                                  Chip(label: Text('Invite user')),
                                                ],
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
