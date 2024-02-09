import 'package:flutter/material.dart';
import 'dart:math';

class PostPage extends StatefulWidget {
  @override
  _PostPageState createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  int _loadedRowCount = 8; // Initial number of rows loaded

  List<String> imageUrls = [
    'https://m.media-amazon.com/images/M/MV5BM2Q5YjNjZWMtYThmYy00N2ZjLWE2NDctNmZjMmZjYWE2NjEwXkEyXkFqcGdeQXVyMTAzMDM4MjM0._V1_.jpg',
    'https://m.media-amazon.com/images/M/MV5BZWMyYzFjYTYtNTRjYi00OGExLWE2YzgtOGRmYjAxZTU3NzBiXkEyXkFqcGdeQXVyMzQ0MzA0NTM@._V1_FMjpg_UX1000_.jpg',
    'https://m.media-amazon.com/images/M/MV5BZDY1ZGM4OGItMWMyNS00MDAyLWE2Y2MtZTFhMTU0MGI5ZDFlXkEyXkFqcGdeQXVyMDc5ODIzMw@@._V1_FMjpg_UX1000_.jpg',
    'https://m.media-amazon.com/images/M/MV5BZjQwYjU3OTYtMWVhMi00N2Y2LWEzMDgtMzViN2U4NWI1NmI3XkEyXkFqcGdeQXVyODk2NDQ3MTA@._V1_.jpg',
    'https://m.media-amazon.com/images/M/MV5BNjU3N2QxNzYtMjk1NC00MTc4LTk1NTQtMmUxNTljM2I0NDA5XkEyXkFqcGdeQXVyODE5NzE3OTE@._V1_FMjpg_UX1000_.jpg',
    'https://m.media-amazon.com/images/M/MV5BZTliNWJhM2YtNDc1MC00YTk1LWE2MGYtZmE4M2Y5ODdlNzQzXkEyXkFqcGdeQXVyMzY0MTE3NzU@._V1_FMjpg_UX1000_.jpg',
    'https://m.media-amazon.com/images/M/MV5BZGUzYTI3M2EtZmM0Yy00NGUyLWI4ODEtN2Q3ZGJlYzhhZjU3XkEyXkFqcGdeQXVyNTM0OTY1OQ@@._V1_FMjpg_UX1000_.jpg',
    'https://m.media-amazon.com/images/M/MV5BM2ZmMjEyZmYtOGM4YS00YTNhLWE3ZDMtNzQxM2RhNjBlODIyXkEyXkFqcGdeQXVyMTUzMTg2ODkz._V1_.jpg',
    'https://m.media-amazon.com/images/M/MV5BYmM4MjBkNGMtZjE5Zi00ZDMwLWE5MjYtN2M0MTM2YTQ2MmNlXkEyXkFqcGdeQXVyMjkwOTAyMDU@._V1_.jpg',
    'https://m.media-amazon.com/images/M/MV5BMjE1MzYzNjk3OF5BMl5BanBnXkFtZTgwMzk0MzYwNzE@._V1_QL75_UX190_CR0,2,190,281_.jpg',
    'https://m.media-amazon.com/images/M/MV5BM2JmYzBlNWMtYTEwZC00MjVmLTlmYjEtN2UyMGJiYjcxYTVjXkEyXkFqcGdeQXVyMTkxNjUyNQ@@._V1_FMjpg_UX1000_.jpg',
    'https://m.media-amazon.com/images/M/MV5BODc5YTBhMTItMjhkNi00ZTIxLWI0YjAtNTZmOTY0YjRlZGQ0XkEyXkFqcGdeQXVyODUwNjEzMzg@._V1_FMjpg_UX1000_.jpg',
    'https://i0.wp.com/thenerdsofcolor.org/wp-content/uploads/2021/06/1622874_WM_MO_NoSuddenMove_KA_Publicity_v03.jpg?resize=720%2C1067&ssl=1',
    'https://mlpnk72yciwc.i.optimole.com/cqhiHLc.IIZS~2ef73/w:auto/h:auto/q:75/https://bleedingcool.com/wp-content/uploads/2021/07/MALIGNANT-_-TW-FB.jpeg'
  ];

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
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 56),
            Align(
              alignment: Alignment.topLeft,
              child: _buildBackButton(context), // Back button
            ),
            SizedBox(height: 10),
            _buildSearchBar(), // Search bar
            SizedBox(height: 20),
            Text(
              'Popular Movies & Series',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20), // Reduced gap between title and movie rows
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification scrollInfo) {
                  if (scrollInfo.metrics.pixels ==
                      scrollInfo.metrics.maxScrollExtent) {
                    // Reached the bottom of the list
                    setState(() {
                      _loadedRowCount +=
                          2; // Increase the number of loaded rows
                    });
                  }
                  return true;
                },
                child: ListView.builder(
                  itemCount: _loadedRowCount,
                  itemBuilder: (context, index) {
                    return _buildMovieRow();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        style: TextStyle(color: Colors.white),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(
          Icons.arrow_back,
          color: Colors.white,
          size: 24, // Adjust size of the back button
        ),
      ),
    );
  }

  Widget _buildMovieRow() {
    // Shuffle the list of image URLs
    List<String> shuffledImageUrls = List.from(imageUrls);
    shuffledImageUrls.shuffle();

    return Container(
      height: 200,
      child: Row(
        children: [
          Expanded(child: _buildMoviePoster(shuffledImageUrls[0])),
          SizedBox(width: 4),
          Expanded(child: _buildMoviePoster(shuffledImageUrls[1])),
          SizedBox(width: 4),
          Expanded(child: _buildMoviePoster(shuffledImageUrls[2])),
        ],
      ),
    );
  }

  Widget _buildMoviePoster(String imageUrl) {
    return Container(
      height: 165,
      width: 120,
      child: Card(
        color: Colors.grey,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
