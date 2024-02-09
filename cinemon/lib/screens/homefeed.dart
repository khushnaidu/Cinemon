import 'package:flutter/material.dart';

class HomeFeedPage extends StatefulWidget {
  @override
  _HomeFeedPageState createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> {
  late PageController _pageController;
  late int _currentIndex;
  bool isBack = true;
  double angle = 0;

  List<String> imageUrls = [
    'https://m.media-amazon.com/images/M/MV5BM2NmMDQ1ZWEtNDU4OS00MGIxLWEyMGMtMTM2YmFkYzNhYmMxXkEyXkFqcGdeQXVyMTM1NjM2ODg1._V1_.jpg',
    'https://m.media-amazon.com/images/M/MV5BMDBmYTZjNjUtN2M1MS00MTQ2LTk2ODgtNzc2M2QyZGE5NTVjXkEyXkFqcGdeQXVyNzAwMjU2MTY@._V1_FMjpg_UX1000_.jpg',
    'https://m.media-amazon.com/images/M/MV5BMzUzNDM2NzM2MV5BMl5BanBnXkFtZTgwNTM3NTg4OTE@._V1_.jpg',
  ];

  List<String> profilePhotos = [
    'https://scontent-sjc3-1.cdninstagram.com/v/t51.2885-19/425196711_1057360228655814_8656861244309452057_n.jpg?stp=dst-jpg_s320x320&_nc_ht=scontent-sjc3-1.cdninstagram.com&_nc_cat=106&_nc_ohc=B5Jy-Cnw8ZcAX_dHbIs&edm=AOQ1c0wBAAAA&ccb=7-5&oh=00_AfCupkoBFXZsDWAyyhjV0zn5FPcpE3m45sVumbNnDwOqig&oe=65C6F06D&_nc_sid=8b3546',
    'https://randomuser.me/api/portraits/women/10.jpg',
    'https://randomuser.me/api/portraits/men/10.jpg',
  ];

  List<String> usernames = [
    'User1',
    'User2',
    'User3',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onScroll);
    _currentIndex = 0;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentIndex = _pageController.page!.round();
    if (currentIndex != _currentIndex) {
      setState(() {
        _currentIndex = currentIndex;
      });
    }
  }

  void _flip() {
    setState(() {
      if (angle == 0) {
        angle = 3.14159; // pi
      } else {
        angle = 0;
      }
    });
  }

  Widget _buildItemList(BuildContext context, int index) {
    if (index == imageUrls.length) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return GestureDetector(
      onTap: _flip,
      child: Center(
        child: Container(
          width: 300, // Adjust width here
          height: 400, // Adjust height here
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: angle),
            duration: Duration(milliseconds: 500),
            builder: (BuildContext context, double val, __) {
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(val),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            imageUrls[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfo(int index) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(profilePhotos[index]),
              radius: 20,
            ),
            SizedBox(width: 8),
            Text(
              usernames[index],
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        _buildItemList(context, index),
        SizedBox(height: 8),
        Text(
          '2 hours ago',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Color.fromARGB(255, 3, 1, 32),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemBuilder: (context, index) => _buildProfileInfo(index),
                itemCount: imageUrls.length,
                physics: BouncingScrollPhysics(),
                scrollDirection: Axis.vertical,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color.fromARGB(255, 3, 1, 32),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        currentIndex: 0, // Set index to 0 to always keep home selected
        onTap: (index) {
          if (index == 1) {
            // Navigate to the PostPage when "Post" is tapped
            Navigator.pushNamed(context, '/post');
          } else {
            // Handle navigation for other items if needed
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'Post',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
